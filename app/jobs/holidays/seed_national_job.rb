module Holidays
  class SeedNationalJob < ApplicationJob
    queue_with_priority 1
    queue_as :default

    def perform
      Tenant.find_each { |tenant| SeedNationalCommand.call(tenant) }
    end
  end
end
