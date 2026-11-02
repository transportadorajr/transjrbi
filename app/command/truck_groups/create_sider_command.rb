module TruckGroups
  class CreateSiderCommand
    SIDER_PLATES = %w[BDZ8J90 RHJ3A99 RHJ4E07 RHJ5A51 RHL2C11 SFK0H59 UBL2C11].freeze
    SIX_AXLES = 6
    PREVIOUS_SIX_AXLES_NAME = 'LS'.freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      rename_six_axles

      [sider]
    end

    private

    attr_reader :tenant

    def rename_six_axles
      name = I18n.t('truck_groups.defaults.six_axles')
      return if tenant.truck_groups.exists?(name:)

      tenant.truck_groups.find_by(name: PREVIOUS_SIX_AXLES_NAME)&.update!(name:)
    end

    def sider
      name = I18n.t('truck_groups.defaults.sider')

      tenant.truck_groups.find_by(name:) || create_sider(name)
    end

    def create_sider(name)
      six_axles = tenant.truck_groups.activated.find { |truck_group| truck_group.axles.include?(SIX_AXLES) }
      sider = tenant.truck_groups.create!(name:, plates: SIDER_PLATES, fuel_percentage: six_axles&.fuel_percentage || 0, activated: true)
      copy_fuel_rates(six_axles, sider) if six_axles
      sider
    end

    def copy_fuel_rates(source, target)
      source.fuel_rates.each do |rate|
        target.fuel_rates.find_or_initialize_by(valid_month: rate.valid_month).update!(percentage: rate.percentage)
      end
    end
  end
end
