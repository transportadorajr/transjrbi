module Dashboard
  class TruckGroupAverages
    MONTHS_COUNT = 4
    TOTAL_KEY = 'total'.freeze

    Row = Data.define(:key, :label, :vehicles_count, :averages, :goal_cents) do
      def average_cents(month)
        averages[month]
      end

      def reached?(month)
        goal_cents.present? && averages[month].present? && averages[month] >= goal_cents
      end
    end

    def initialize(tenant, month)
      @tenant = tenant
      @month = month.beginning_of_month
    end

    def months
      @months ||= (MONTHS_COUNT - 1).downto(0).map { |offset| month.months_ago(offset) }
    end

    def rows
      @rows ||= targets.options(:truck_groups).map do |key, label|
        Row.new(key:, label:, vehicles_count: targets.truck_group_plates.fetch(key, []).size,
                averages: months.index_with { |month| month_averages(month)[key] }, goal_cents: targets.goal_amounts(:truck_groups)[key])
      end
    end

    def total_row
      Row.new(key: TOTAL_KEY, label: I18n.t('goals.truck_groups.total'), vehicles_count: targets.truck_group_plates.values.sum(&:size),
              averages: months.index_with { |month| month_total_average(month) }, goal_cents: nil)
    end

    private

    attr_reader :tenant, :month

    def targets
      month_targets(month)
    end

    def month_targets(month)
      @month_targets ||= {}
      @month_targets[month] ||= RevenueGoal::Targets.new(tenant, month)
    end

    def month_averages(month)
      @month_averages ||= {}
      @month_averages[month] ||= month_targets(month).billing(:truck_groups, issued(month))
    end

    def month_total_average(month)
      plates = month_targets(month).truck_group_plates.values.flatten
      return if plates.empty?

      (issued(month).where(plate: plates).sum(:freight_cents).to_d / plates.size).round.to_i
    end

    def issued(month)
      tenant.billable_freights.active.not_canceled.where(issued_at: month.beginning_of_day..month.end_of_month.end_of_day)
    end
  end
end
