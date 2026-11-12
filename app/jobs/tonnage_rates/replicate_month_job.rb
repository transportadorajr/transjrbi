module TonnageRates
  class ReplicateMonthJob < ApplicationJob
    queue_with_priority 1
    queue_as :default

    def perform
      Tenant.find_each do |tenant|
        FreightExpenses::CalculateJob.perform_later(tenant.id) if ReplicateMonthCommand.call(tenant).any?
      end
    end
  end
end
