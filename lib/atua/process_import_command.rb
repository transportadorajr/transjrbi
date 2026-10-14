module Atua
  class ProcessImportCommand
    class << self
      def call(import)
        new(import).call
      end
    end

    def initialize(import)
      @import = import
    end

    def call
      spreadsheet = read_spreadsheet
      result = ActiveRecord::Base.transaction { SaveReportCommand.for(import.report_type).call(import, spreadsheet) }

      import.succeed!(
        rows_read: spreadsheet.rows.size, inserted_count: result.inserted, updated_count: result.updated,
        removed_count: result.removed, warning_message: result.warning
      )
      import
    rescue StandardError => e
      FailImportCommand.call(import, e)
    end

    private

    attr_reader :import

    def read_spreadsheet
      raise Error, I18n.t('atua.errors.missing_file', id: import.id) unless import.file.attached?

      import.file.open { |file| ReadSpreadsheetCommand.call(import.tenant, file.path) }
    end
  end
end
