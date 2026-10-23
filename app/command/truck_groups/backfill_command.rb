module TruckGroups
  class BackfillCommand
    DEFAULTS = { rodotrem: [9], quarto_eixo: [7], ls: [6] }.freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      return tenant.truck_groups.to_a if tenant.truck_groups.exists?

      defaults = DEFAULTS.map do |key, axles|
        tenant.truck_groups.create!(name: I18n.t(key, scope: 'truck_groups.defaults'), axles:, fuel_percentage: 0,
                                    activated: true)
      end

      defaults << CreateRemainingAxlesCommand.call(tenant)
    end

    private

    attr_reader :tenant
  end
end
