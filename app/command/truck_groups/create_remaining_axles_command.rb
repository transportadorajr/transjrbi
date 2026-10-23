module TruckGroups
  class CreateRemainingAxlesCommand
    class << self
      def call(tenant, fuel_percentage: 0)
        new(tenant, fuel_percentage:).call
      end
    end

    def initialize(tenant, fuel_percentage:)
      @tenant = tenant
      @fuel_percentage = fuel_percentage
    end

    def call
      existing = tenant.truck_groups.find_by(remaining_axles: true)
      return existing if existing

      tenant.truck_groups.create!(name: I18n.t('truck_groups.defaults.others'), axles: [], remaining_axles: true, fuel_percentage:,
                                  activated: true)
    end

    private

    attr_reader :tenant, :fuel_percentage
  end
end
