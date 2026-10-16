module TonnageRates
  class BackfillCommand
    GROUP_NAME = 'USIMINAS'.freeze
    NAME = 'Brasiltec'.freeze
    VALID_MONTH = Date.new(2026, 10, 1)
    RATES = [
      { nickname: 'Cubatão', origin_city: 'Cubatão', origin_state: 'SP', rate_cents: 1_257 },
      { nickname: 'Utinga', origin_city: 'Santo André', origin_state: 'SP', rate_cents: 1_802 },
      { nickname: 'Ipatinga', origin_city: 'Ipatinga', origin_state: 'MG', rate_cents: 860 },
      { nickname: 'TESP', origin_city: 'São Paulo', origin_state: 'SP', rate_cents: 880 },
    ].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      group = tenant.customer_groups.for_name(GROUP_NAME)
      return [] unless group
      return group.tonnage_rates.to_a if group.tonnage_rates.exists?

      rates = RATES.map do |attributes|
        group.tonnage_rates.create!(tenant:, name: NAME, valid_month: VALID_MONTH, activated_at: Time.current, **attributes)
      end
      FreightExpenses::CalculateTonnageCommand.call(tenant)

      rates
    end

    private

    attr_reader :tenant
  end
end
