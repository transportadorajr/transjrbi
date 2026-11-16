class RevenueGoal
  class Targets
    SECTIONS = { vehicles: 'vehicle', customer_groups: 'customer_group', regions: 'region' }.freeze

    def initialize(tenant, month)
      @tenant = tenant
      @month = month.beginning_of_month
    end

    attr_reader :month

    def goals
      @goals ||= tenant.revenue_goals.for_month(month).to_a
    end

    def options(section)
      @options ||= {}
      @options[section] ||= send(:"#{section}_options")
    end

    def reference_cents(section)
      @reference_cents ||= {}
      @reference_cents[section] ||= billing(section, billed(month.prev_month.all_month))
    end

    def billing(section, relation)
      send(:"#{section}_billing", relation).transform_keys(&:to_s)
    end

    def goal_amounts(section)
      goals.select { |goal| goal.target_type == SECTIONS.fetch(section) }.to_h { |goal| [goal.target_value.to_s, goal.amount_cents] }
    end

    private

    attr_reader :tenant

    def billed(period)
      tenant.billable_freights.active.not_canceled.where(issued_at: period.first.beginning_of_day..period.last.end_of_day)
    end

    def goal_values(section)
      goal_amounts(section).keys
    end

    def vehicles_options
      (tenant.own_fleet&.plates.to_a | goal_values(:vehicles)).sort.index_with(&:itself)
    end

    def customer_groups_options
      RevenueGoal.listed_customer_groups(tenant, goal_values(:customer_groups)).to_h { |group| [group.id.to_s, group.name] }
    end

    def regions_options
      tenant.macro_regions.order(:name, :id).to_h { |region| [region.id.to_s, region.name] }
    end

    def vehicles_billing(relation)
      relation.group(:plate).sum(:freight_cents)
    end

    def customer_groups_billing(relation)
      relation.left_joins(:taker).group(Atua::Customer.arel_table[:customer_group_id]).sum(:freight_cents)
    end

    def regions_billing(relation)
      relation.group(:origin_macro_region_id).sum(:freight_cents)
    end
  end
end
