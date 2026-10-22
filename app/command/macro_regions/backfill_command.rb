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
      return tenant.macro_regions.to_a if tenant.macro_regions.exists?

      regions = defaults.map { |attributes| tenant.macro_regions.create!(attributes) }
      AssignCommand.call(tenant)

      regions
    end

    private

    attr_reader :tenant

    def defaults
      YAML.load_file(DEFAULTS_PATH).map(&:symbolize_keys)
    end
  end
end
