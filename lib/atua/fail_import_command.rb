module Atua
  class FailImportCommand
    FAILURE_STREAK = 3

    class << self
      def call(import, error)
        new(import, error).call
      end
    end

    def initialize(import, error)
      @import = import
      @error = error
    end

    def call
      Rails.logger.error("[Atua] Import #{import.id} (#{import.report_type}) failed: #{error.class.name} #{error.message}")
      import.fail!(error.message, error_type:)
      notify_failure_streak if failure_streak_reached?

      import
    end

    private

    attr_reader :import, :error

    def error_type
      return :unexpected unless error.is_a?(Error)

      type = error.class.name.demodulize.underscore.delete_suffix('_error').to_sym
      Import::ERROR_TYPES.include?(type) ? type : :unexpected
    end

    def failure_streak_reached?
      statuses = import.tenant.atua_imports.where(report_type: import.report_type).where.not(finished_at: nil)
        .order(finished_at: :desc, id: :desc).limit(FAILURE_STREAK + 1).pluck(:status_type)

      statuses.first(FAILURE_STREAK).count('failed') == FAILURE_STREAK && statuses[FAILURE_STREAK] != 'failed'
    end

    def notify_failure_streak
      Rails.logger.error(
        "[Atua] #{FAILURE_STREAK} consecutive failures of #{import.report_type} for tenant #{import.tenant_id}: #{error.message}",
      )
      return unless Admin::User.exists?

      ImportMailer.repeated_failures(import).deliver_later
    end
  end
end
