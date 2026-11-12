module TonnageRates
  class ReplicateMonthCommand
    COPIED_ATTRIBUTES = %w[tenant_id customer_group_id name nickname origin_city origin_state rate_cents activated_at].freeze

    class << self
      def call(tenant, month = Date.current)
        new(tenant, month).call
      end
    end

    def initialize(tenant, month)
      @tenant = tenant
      @month = month.to_date.beginning_of_month
    end

    def call
      TonnageRate.transaction do
        sources.map do |source|
          tenant.tonnage_rates.create!(**source.attributes.slice(*COPIED_ATTRIBUTES), valid_month: month, copied_from: source)
        end
      end
    end

    private

    attr_reader :tenant, :month

    def sources
      filled = tenant.tonnage_rates.where(valid_month: month).to_set(&:series_key)

      tenant.tonnage_rates.activated.where(valid_month: ...month).group_by(&:series_key)
        .except(*filled)
        .map { |_key, rates| rates.max_by { |rate| [rate.valid_month, rate.id] } }
    end
  end
end
