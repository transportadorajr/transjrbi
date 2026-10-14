module Atua
  class Report
    TYPES = %i[transport_documents manifests expenses customers vehicles].freeze
    DIRECTORY = Rails.root.join('config/atua/reports')
    DATE_FORMAT = '%d/%m/%Y'.freeze
    SUBMIT_VALUE = 'Gerar'.freeze
    MAX_PERIOD_DAYS = 31

    attr_reader :type, :endpoint, :submitted_field, :submit_button, :start_field, :end_field

    class << self
      def find(type)
        type = type.to_sym
        raise ArgumentError, I18n.t('atua.errors.unknown_report', type:) unless TYPES.include?(type)

        new(type, YAML.load_file(DIRECTORY.join("#{type}.yml")))
      end

      def all
        TYPES.map { |type| find(type) }
      end
    end

    def initialize(type, definition)
      @type = type
      @endpoint = definition.fetch('endpoint')
      @submitted_field = definition.fetch('submitted_field')
      @submit_button = definition['submit_button']
      @start_field = definition.dig('period', 'start_field')
      @end_field = definition.dig('period', 'end_field')
      @computed = definition.fetch('computed', {})
      @params = definition.fetch('params')
    end

    def period?
      start_field.present?
    end

    def form?
      submit_button.present?
    end

    def periods(start_date, end_date)
      unless period?
        raise ArgumentError, I18n.t('atua.errors.period_not_supported', report: type) if start_date || end_date

        return [[nil, nil]]
      end

      start_date = (start_date || Time.zone.today.beginning_of_month).to_date
      end_date = (end_date || Time.zone.today).to_date
      raise ArgumentError, I18n.t('atua.errors.invalid_period') if start_date > end_date

      monthly_slices(start_date, end_date)
    end

    def form_params(start_date: nil, end_date: nil, button: submit_button)
      values = { submitted_field => '1' }
      values.merge!(params)
      values.merge!(computed_values)
      if period?
        values[start_field] = format_date(start_date)
        values[end_field] = format_date(end_date)
      end
      values[button] = SUBMIT_VALUE if button.present?

      values
    end

    private

    attr_reader :params, :computed

    def monthly_slices(start_date, end_date)
      return [[start_date, end_date]] if (end_date - start_date).to_i < MAX_PERIOD_DAYS

      slices = []
      cursor = start_date

      while cursor <= end_date
        slice_end = [cursor.end_of_month, end_date].min
        slices << [cursor, slice_end]
        cursor = slice_end + 1
      end

      slices
    end

    def computed_values
      computed.transform_values do |value|
        case value
        when 'today' then format_date(Time.zone.today)
        else raise ArgumentError, I18n.t('atua.errors.unknown_computed_value', value:)
        end
      end
    end

    def format_date(date)
      date.strftime(DATE_FORMAT)
    end
  end
end
