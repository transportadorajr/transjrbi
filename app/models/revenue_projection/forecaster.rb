module RevenueProjection
  class Forecaster
    BASELINE_DAYS = 84
    MEDIAN = 0.5
    LOW = 0.25
    HIGH = 0.75

    Forecast = Data.define(:date, :day_type, :typical_cents, :factor, :forecast_cents, :low_cents, :high_cents)

    def initialize(daily_totals, calendar, factors)
      @daily_totals = daily_totals
      @calendar = calendar
      @factors = factors
    end

    def forecast(date, as_of: date)
      values = typical_values(date.wday, as_of)
      return if values.empty?

      day_type = calendar.day_type(date)
      factor = factors.day_factor(day_type, date.wday)

      Forecast.new(date:, day_type:, typical_cents: percentile(values, MEDIAN).round, factor:,
                   forecast_cents: (percentile(values, MEDIAN) * factor).round, low_cents: (percentile(values, LOW) * factor).round,
                   high_cents: (percentile(values, HIGH) * factor).round)
    end

    def share_until(wday, hours, as_of:)
      hourly = baseline_days(wday, as_of).map(&:hourly_cents).reject(&:empty?)
      total = hourly.sum(&:sum)
      return hours / DailyTotal::HOURS if total.zero?

      hour = hours.floor.clamp(0, DailyTotal::HOURS - 1)
      until_hour = hourly.sum { |cents| cents.first(hour).sum + (cents[hour] * (hours - hour)) }

      until_hour / total.to_f
    end

    def history_days(as_of)
      window(as_of).count { calendar.day_type(it.date) == :regular }
    end

    private

    attr_reader :daily_totals, :calendar, :factors

    def window(as_of)
      ((as_of - BASELINE_DAYS)...as_of).filter_map { daily_totals[it] }
    end

    def baseline_days(wday, as_of)
      window(as_of).select { it.wday == wday && calendar.day_type(it.date) == :regular }
    end

    def typical_values(wday, as_of)
      baseline_days(wday, as_of).map { it.billed_cents.to_f }.sort
    end

    def percentile(values, percentile)
      rank = percentile * (values.size - 1)
      lower = values[rank.floor]

      lower + ((values[rank.ceil] - lower) * (rank - rank.floor))
    end
  end
end
