module Atua
  class ReadSpreadsheetCommand
    TOTALS_ROW = 1
    HEADER_ROW = 2
    FIRST_DATA_ROW = 3
    TOTALS_TOLERANCE = BigDecimal('0.01')

    Result = Data.define(:headers, :rows)

    class << self
      def call(tenant, path)
        new(tenant, path).call
      end
    end

    def initialize(tenant, path)
      @tenant = tenant
      @path = path
    end

    def call
      rows = data_rows
      verify_totals(rows)

      Result.new(headers: headers.compact, rows:)
    end

    private

    attr_reader :tenant, :path

    def sheet
      @sheet ||= Roo::Excel.new(path.to_s, extension: :xls, file_warning: :ignore).sheet(0)
    rescue Ole::Storage::FormatError, TypeError, IOError, SystemCallError => e
      raise SpreadsheetError, I18n.t('atua.errors.unreadable_spreadsheet', file: File.basename(path.to_s), reason: e.message)
    end

    def headers
      @headers ||= sheet.row(HEADER_ROW).map { |header| header.to_s.strip.presence }
    end

    def data_rows
      return [] if sheet.last_row.to_i < FIRST_DATA_ROW

      (FIRST_DATA_ROW..sheet.last_row).filter_map do |index|
        values = sheet.row(index)
        next if values.all? { |value| blank_cell?(value) }

        headers.each_with_index.with_object({}) do |(header, position), row|
          row[header] = values[position] if header
        end
      end
    end

    def verify_totals(rows)
      mismatches = totals.filter_map do |header, expected|
        actual = rows.sum(BigDecimal(0)) { |row| row[header].is_a?(Numeric) ? BigDecimal(row[header].to_s) : 0 }
        next if (actual - expected).abs <= TOTALS_TOLERANCE

        I18n.t('atua.errors.totals_column', column: header, expected: expected.to_s('F'), actual: actual.to_s('F'))
      end
      return if mismatches.empty?

      raise SpreadsheetError, I18n.t('atua.errors.totals_mismatch', file: File.basename(path.to_s), columns: mismatches.to_sentence)
    end

    def totals
      sheet.row(TOTALS_ROW).each_with_index.with_object({}) do |(value, position), totals|
        header = headers[position]
        totals[header] = BigDecimal(value.to_s) if header && value.is_a?(Numeric)
      end
    end

    def blank_cell?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end
  end
end
