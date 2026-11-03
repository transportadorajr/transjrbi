module MacroRegions
  class AssignRemainingStateCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      cities_without_region.distinct.pluck(:state).sum do |state|
        cities_without_region.where(state:).update_all(macro_region_id: remaining_region(state).id, updated_at: Time.current)
      end
    end

    private

    attr_reader :tenant

    def cities_without_region
      tenant.cities.where(macro_region_id: nil, state: MacroRegion::BRAZILIAN_STATES)
    end

    def remaining_region(state)
      tenant.macro_regions.find_by(state:, remaining_state: true) ||
        tenant.macro_regions.create!(name: I18n.t("macro_regions.remaining_state_names.#{state}"), state:, remaining_state: true)
    end
  end
end
