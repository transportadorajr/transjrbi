module RevenueProjections
  class RefreshCurrentJob < ApplicationJob
    queue_with_priority 1
    queue_as :default

    def perform
      Tenant.find_each do |tenant|
        RefreshCurrentCommand.call(tenant) if tenant.atua_transport_documents.exists?
      end
    end
  end
end
