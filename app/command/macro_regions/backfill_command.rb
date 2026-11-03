module MacroRegions
  class BackfillCommand
    DEFAULTS_PATH = Rails.root.join('config/macro_regions.yml')

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      regions = ActiveRecord::Base.transaction { defaults.map { |attributes| save_region(attributes) } }
      AssignRemainingStateCommand.call(tenant)
      AssignCommand.call(tenant)

      regions
    end

    private

    attr_reader :tenant

    def defaults
      YAML.load_file(DEFAULTS_PATH).map(&:symbolize_keys)
    end

    def save_region(attributes)
      region = find_region(attributes) || new_region(attributes)
      region.update!(name: attributes[:name])
      Array(attributes[:cities]).each { |name| attach_city(region, name) } unless region.remaining_state?

      region
    end

    def find_region(attributes)
      regions = tenant.macro_regions

      regions.find_by(name: attributes[:name]) ||
        regions.find_by(name: Array(attributes[:previous_names])) ||
        (regions.find_by(state: attributes[:state], remaining_state: true) if attributes[:remaining_state])
    end

    def new_region(attributes)
      tenant.macro_regions.new(state: attributes[:state], remaining_state: attributes.fetch(:remaining_state, false))
    end

    def attach_city(region, name)
      city = cities_of(region.state)[CustomerGroup.compact(name)]

      if city.nil?
        cities_of(region.state)[CustomerGroup.compact(name)] = tenant.cities.create!(name:, state: region.state, macro_region: region)
      elsif city.macro_region_id.nil? || city.macro_region.remaining_state?
        city.update!(macro_region: region)
      end
    end

    def cities_of(state)
      @cities ||= {}
      @cities[state] ||= tenant.cities.where(state:).index_by(&:compacted_name)
    end
  end
end
