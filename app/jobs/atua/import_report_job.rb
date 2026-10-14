module Atua
  class ImportReportJob < ApplicationJob
    queue_with_priority 1
    include GoodJob::ActiveJobExtensions::Concurrency

    SESSION_LABEL = 'atua-session'.freeze
    RETRY_WAIT = 30.minutes
    RETRY_ATTEMPTS = 3

    queue_as :atua

    self.good_job_labels = [-> { report_label }, -> { period_label }, SESSION_LABEL]

    good_job_concurrency_rule(label: -> { period_label }, enqueue_limit: 1)
    good_job_concurrency_rule(label: -> { report_label }, perform_limit: 1)
    good_job_concurrency_rule(label: SESSION_LABEL, perform_limit: 1)

    discard_on AuthenticationError, ConfigurationError
    retry_on UnavailableError, wait: RETRY_WAIT, attempts: RETRY_ATTEMPTS

    class << self
      def report_label(tenant_id = nil, report_type = nil)
        "atua-import:#{tenant_id}:#{report_type}"
      end
    end

    def perform(tenant_id, report_type, start_date = nil, end_date = nil)
      ImportReportCommand.call(Tenant.find(tenant_id), report_type, start_date:, end_date:, raise_errors: true)
    rescue SessionError, DownloadError => e
      raise unless e.server_unavailable?

      raise UnavailableError.new(e.message, status: e.status, headers: e.headers, body_excerpt: e.body_excerpt)
    end

    private

    def report_label
      self.class.report_label(*arguments.first(2))
    end

    def period_label
      [report_label, *arguments.values_at(2, 3)].join(':')
    end
  end
end
