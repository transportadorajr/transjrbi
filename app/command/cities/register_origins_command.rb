module Cities
  class RegisterOriginsCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      cities = ActiveRecord::Base.transaction { missing_origins.map { |name, state| tenant.cities.create!(name:, state:) } }
      MacroRegions::AssignRemainingStateCommand.call(tenant)

      cities
    end

    private

    attr_reader :tenant

    def missing_origins
      origins.reject { |name, state| registered.include?([CustomerGroup.compact(name), state]) }
        .uniq { |name, state| [CustomerGroup.compact(name), state] }
    end

    def origins
      tenant.atua_transport_documents.distinct.pluck(:origin_city, :origin_state)
        .map { |name, state| [name.to_s.squish, state.to_s.strip.upcase] }
        .select { |name, state| CustomerGroup.compact(name).present? && MacroRegion::BRAZILIAN_STATES.include?(state) }
    end

    def registered
      @registered ||= tenant.cities.pluck(:name, :state).to_set { |name, state| [CustomerGroup.compact(name), state] }
    end
  end
end
