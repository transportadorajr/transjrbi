class RevenueGoal
  class Week
    WEEK_START = :sunday

    def initialize(reference_date, goals:, holidays:)
      @reference_date = reference_date
      @goals = goals
      @calendar = BusinessCalendar.new(holidays)
    end

    attr_reader :reference_date

    def period
      @period ||= reference_date.all_week(WEEK_START)
    end

    def months
      period.map(&:beginning_of_month).uniq
    end

    def goal_cents(target_type, value = nil)
      shares = calendar.business_days(period).filter_map do |date|
        goal = goal_for(date.beginning_of_month, target_type.to_s, value)
        goal.amount_cents.to_d / month_business_days(date.beginning_of_month) if goal
      end

      shares.sum.round if shares.any?
    end

    private

    attr_reader :goals, :calendar

    def goal_for(month, target_type, value)
      goals.find { |goal| goal.month == month && goal.target_type == target_type && goal.target_value&.to_s == value&.to_s }
    end

    def month_business_days(month)
      @month_business_days ||= {}
      @month_business_days[month] ||= calendar.business_days(month.all_month).size
    end
  end
end
