module FreightExpenses
  class CalculateJob < ApplicationJob
    queue_with_priority 5
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :default

    good_job_control_concurrency_with(perform_limit: 1, key: -> { "freight-expenses:#{arguments.first}" })

    def perform(tenant_id)
      tenant = Tenant.find(tenant_id)

      CustomerGroups::RecalculateCommand.call(tenant)
      CalculateCommissionsCommand.call(tenant)
      CalculateTonnageCommand.call(tenant)
      CalculateInsuranceCommand.call(tenant)
    end
  end
end
