module Atua
  class MapReportCommand
    REPORT = nil
    COLUMNS = {}.freeze
    DOCUMENT_COLUMNS = {}.freeze
    SPECIAL_COLUMNS = [].freeze
    RAW_COLUMNS = [].freeze
    REQUIRED_COLUMNS = [].freeze

    class << self
      def call(tenant, spreadsheet, previous: {})
        new(tenant, spreadsheet, previous:).call
      end

      def known_columns
        self::COLUMNS.keys + self::DOCUMENT_COLUMNS.keys + self::SPECIAL_COLUMNS + self::RAW_COLUMNS
      end
    end

    def initialize(tenant, spreadsheet, previous: {})
      @tenant = tenant
      @spreadsheet = spreadsheet
      @previous = previous
      @imported_at = Time.current
    end

    def call
      verify_layout
      log_unknown_columns

      map(spreadsheet.rows)
    end

    private

    attr_reader :tenant, :spreadsheet, :previous, :imported_at

    def report
      self.class::REPORT
    end

    def map(rows)
      raise NotImplementedError
    end

    def verify_layout
      missing = self.class::REQUIRED_COLUMNS - spreadsheet.headers
      return if missing.empty?

      raise LayoutError, I18n.t('atua.errors.missing_columns', report:, missing: missing.join(', '), received: spreadsheet.headers.join(', '))
    end

    def log_unknown_columns
      unknown = spreadsheet.headers - self.class.known_columns
      return if unknown.empty?

      Rails.logger.info(I18n.t('atua.errors.unknown_columns', report:, columns: unknown.join(', ')))
    end

    def map_columns(row)
      attributes = self.class::COLUMNS.each_with_object({}) do |(column, (attribute, type, options)), mapped|
        mapped[attribute] = convert(row, column, type, **options.to_h)
      end

      self.class::DOCUMENT_COLUMNS.each do |column, attribute|
        attributes[attribute] = convert(row, column, :string)
        attributes[:"#{attribute}_digits"] = convert(row, column, :document)
      end

      attributes
    end

    def convert(row, column, type, **)
      convert_value(row[column], type, column:, **)
    end

    def convert_value(value, type, column:, **)
      ConvertValueCommand.call(tenant, value, type, **)
    rescue ConversionError => e
      raise ConversionError, I18n.t('atua.errors.column_conversion', column:, report:, message: e.message)
    end

    def yes_no(row, column, key:, attribute:, date: nil)
      convert(row, column, :yes_no, date:, previous: previous.dig(key, attribute), now: imported_at)
    end
  end
end
