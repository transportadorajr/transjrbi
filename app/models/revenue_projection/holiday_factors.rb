module RevenueProjection
  class HolidayFactors
    DEFAULTS = { weekday: 0.30, saturday: 0.80, bridge_day: 0.60, optional: 0.50 }.freeze
    MIN_OBSERVATIONS = 2
    NEIGHBOR_WEEKS = 4

    class << self
      def category(holiday)
        return if holiday.nil? || holiday.date.sunday?
        return :bridge_day if holiday.bridge_day?
        return :optional if holiday.optional?

        holiday.date.saturday? ? :saturday : :weekday
      end
    end

    def initialize(holidays, daily_totals)
      @holidays = holidays
      @daily_totals = daily_totals
    end

    def factor(date)
      category = self.class.category(holidays[date])

      category ? factors.fetch(category) : 1.0
    end

    def factors
      @factors ||= DEFAULTS.to_h do |category, default|
        values = observations.fetch(category, [])

        [category, values.size >= MIN_OBSERVATIONS ? median(values).clamp(0.0, 1.0).round(2) : default]
      end
    end

    private

    attr_reader :holidays, :daily_totals

    def observations
      @observations ||= holidays.each_value.with_object({}) do |holiday, result|
        category = self.class.category(holiday)
        ratio = observed_ratio(holiday.date) if category

        (result[category] ||= []) << ratio if ratio
      end
    end

    def observed_ratio(date)
      return unless daily_totals.key?(date)

      neighbors = (-NEIGHBOR_WEEKS..NEIGHBOR_WEEKS).filter_map do |weeks|
        neighbor = date + (weeks * 7)
        daily_totals[neighbor] if weeks.nonzero? && daily_totals.key?(neighbor) && !holidays.key?(neighbor)
      end
      typical = median(neighbors)

      daily_totals[date] / typical.to_f if typical&.positive?
    end

    def median(values)
      return if values.empty?

      sorted = values.sort
      middle = sorted.size / 2

      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end
  end
end
