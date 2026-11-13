module RevenueGoals
  class ReplicateMonthCommand
    COPIED_ATTRIBUTES = %w[target_type plate customer_group_id amount_cents].freeze

    class << self
      def call(tenant, month)
        new(tenant, month).call
      end
    end

    def initialize(tenant, month)
      @tenant = tenant
      @month = month.to_date.beginning_of_month
    end

    def call
      RevenueGoal.transaction do
        sources.map { |source| tenant.revenue_goals.create!(**source.attributes.slice(*COPIED_ATTRIBUTES), month:) }
      end
    end

    private

    attr_reader :tenant, :month

    def sources
      filled = tenant.revenue_goals.for_month(month).to_set { |goal| target_key(goal) }

      tenant.revenue_goals.for_month(month.prev_month).reject { |goal| filled.include?(target_key(goal)) }
    end

    def target_key(goal)
      [goal.target_type, goal.plate, goal.customer_group_id]
    end
  end
end
