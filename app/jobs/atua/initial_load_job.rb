module Atua
  class InitialLoadJob < ApplicationJob
    queue_with_priority 1
    queue_as :atua

    def perform(tenant_id, start_date, production_access: false)
      InitialLoadCommand.call(Tenant.find(tenant_id), start_date, production_access:)
    end
  end
end
