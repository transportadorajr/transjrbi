module Atua
  class ProcessImportCommand
    EMPTY_LEG_REPORTS = %w[manifests transport_documents].freeze
    EXPENSE_LINK_REPORTS = %w[expenses transport_documents vehicles].freeze
    COMMISSION_REPORTS = %w[customers transport_documents].freeze

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
      import.file.purge
      calculate_empty_legs
      link_expenses
      calculate_commissions
      import
    rescue StandardError => e
      FailImportCommand.call(import, e)
    end

    private

    attr_reader :import

    def calculate_empty_legs
      return unless EMPTY_LEG_REPORTS.include?(import.report_type)

      EmptyLegs::ScheduleCalculationCommand.call(import.tenant_id, import.start_date&.iso8601)
    end

    def link_expenses
      return unless EXPENSE_LINK_REPORTS.include?(import.report_type)

      LinkExpensesJob.perform_later(import.tenant_id)
    end

    def calculate_commissions
      return unless COMMISSION_REPORTS.include?(import.report_type)

      FreightExpenses::CalculateJob.perform_later(import.tenant_id)
    end

    def read_spreadsheet
      raise Error, I18n.t('atua.errors.missing_file', id: import.id) unless import.file.attached?

      import.file.open { |file| ReadSpreadsheetCommand.call(import.tenant, file.path) }
    end
  end
end
