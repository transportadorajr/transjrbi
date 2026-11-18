module Atua
  class NotifyImportFailureCommand
    SOURCE = 'atua.import_report'.freeze

    class << self
      def call(tenant_id, report_type, start_date = nil, end_date = nil, error:, attempts:)
        new(tenant_id, report_type, start_date, end_date, error:, attempts:).call
      end
    end

    def initialize(tenant_id, report_type, start_date, end_date, error:, attempts:)
      @tenant = Tenant.find_by(id: tenant_id)
      @tenant_id = tenant_id
      @report_type = report_type
      @start_date = start_date
      @end_date = end_date
      @error = error
      @attempts = attempts
    end

    def call
      failure = ImportFailedError.new(message)
      failure.set_backtrace(original_error.backtrace || caller)

      Rails.logger.error("[Atua] #{failure.message}")
      Discord::NotifyErrorCommand.call(failure, handled: false, context: { tenant_id: }, source: SOURCE) if Discord.enabled?

      failure
    end

    private

    attr_reader :tenant, :tenant_id, :report_type, :start_date, :end_date, :error, :attempts

    def message
      I18n.t(
        'atua.errors.import_failed',
        report: Import.human_enum_name(:report_type, report_type),
        tenant: tenant&.trade_name || tenant_id,
        period:,
        attempts:,
        reason: original_error.message,
      )
    end

    def period
      return I18n.t('atua.errors.import_without_period') unless start_date && end_date

      I18n.t('atua.errors.import_period', start_date: I18n.l(start_date.to_date), end_date: I18n.l(end_date.to_date))
    end

    def original_error
      error.cause || error
    end
  end
end
