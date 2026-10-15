module Atua
  class LinkExpensesJob < ApplicationJob
    queue_with_priority 5
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :default

    good_job_control_concurrency_with(perform_limit: 1, key: -> { "link-expenses:#{arguments.first}" })

    def perform(tenant_id)
      LinkExpensesCommand.call(Tenant.find(tenant_id))
    end
  end
end
