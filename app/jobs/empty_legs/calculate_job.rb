module EmptyLegs
  class CalculateJob < ApplicationJob
    queue_with_priority 5
    include GoodJob::ActiveJobExtensions::Concurrency

    RETRY_WAIT = 30.minutes
    RETRY_ATTEMPTS = 3

    queue_as :default

    good_job_control_concurrency_with(perform_limit: 1, key: -> { self.class.concurrency_key(arguments.first) })

    discard_on Tomtom::ConfigurationError
    retry_on Tomtom::RequestError, wait: RETRY_WAIT, attempts: RETRY_ATTEMPTS

    class << self
      def concurrency_key(tenant_id)
        "empty-legs:#{tenant_id}"
      end
    end

    def perform(tenant_id, start_date = nil)
      CalculateAllCommand.call(Tenant.find(tenant_id), start_date:)
    end
  end
end
