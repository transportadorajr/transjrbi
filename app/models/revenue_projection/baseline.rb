module RevenueProjection
  class Baseline
    MEDIAN = 0.5
    LOW = 0.25
    HIGH = 0.75
    HOURS = 24

    def initialize(daily_totals, hourly_totals)
      @daily_totals = daily_totals
      @hourly_totals = hourly_totals
    end

    def days_count
      daily_totals.size
    end

    def typical(wday, percentile = MEDIAN)
      values = daily_values.fetch(wday, [])
      return 0.0 if values.empty?

      rank = percentile * (values.size - 1)
      lower = values[rank.floor]

      lower + ((values[rank.ceil] - lower) * (rank - rank.floor))
    end

    def share_until(wday, hours)
      totals = hourly_values.fetch(wday) { Array.new(HOURS, 0) }
      total = totals.sum
      return hours / HOURS if total.zero?

      hour = hours.floor.clamp(0, HOURS - 1)

      (totals.first(hour).sum + (totals[hour] * (hours - hour))) / total.to_f
    end

    private

    attr_reader :daily_totals, :hourly_totals

    def daily_values
      @daily_values ||= daily_totals.group_by { |date, _cents| date.wday }.transform_values { |pairs| pairs.map { it.last.to_f }.sort }
    end

    def hourly_values
      @hourly_values ||= hourly_totals.each_with_object({}) do |(time, cents), totals|
        hours = totals[time.wday] ||= Array.new(HOURS, 0)
        hours[time.hour] += cents.to_i
      end
    end
  end
end
