module Drivers
  class ExcludeCommand
    class << self
      def call(tenant, driver)
        new(tenant, driver).call
      end
    end

    def initialize(tenant, driver)
      @tenant = tenant
      @driver = driver
    end

    def call
      ExcludedDriver.transaction do
        excluded_driver = tenant.excluded_drivers.find_or_create_by!(code: driver.driver_code) { |record| record.name = driver.driver_name }
        Atua::PurgeInactiveDriversCommand.call(tenant)
        excluded_driver
      end
    end

    private

    attr_reader :tenant, :driver
  end
end
