module TruckGroups
  class CreateUtingaAndFiveAxlesCommand
    UTINGA_PLATES = %w[BAV5A04 BCN1A44 BEC3D14 EVO8C24 EVU4D57].freeze
    UTINGA_FUEL_PERCENTAGE = 28
    FIVE_AXLES = 5
    FIVE_AXLES_FUEL_PERCENTAGE = 35

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      [utinga, five_axles]
    end

    private

    attr_reader :tenant

    def utinga
      name = I18n.t('truck_groups.defaults.utinga')

      tenant.truck_groups.find_by(name:) ||
        tenant.truck_groups.create!(name:, plates: UTINGA_PLATES, fuel_percentage: UTINGA_FUEL_PERCENTAGE, activated: true)
    end

    def five_axles
      name = I18n.t('truck_groups.defaults.five_axles')

      tenant.truck_groups.find_by(name:) || tenant.truck_groups.activated.find { |truck_group| truck_group.axles.include?(FIVE_AXLES) } ||
        tenant.truck_groups.create!(name:, axles: [FIVE_AXLES], fuel_percentage: FIVE_AXLES_FUEL_PERCENTAGE, activated: true)
    end
  end
end
