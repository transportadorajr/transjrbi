module RevenueProjection
  Replay = Data.define(:totals_by_date, :forecasts_by_date, :snapshots) do
    def recalculated?
      true
    end

    def snapshots_of(period_type, period_start)
      snapshots.select { it.period_type == period_type.to_s && it.period_start == period_start }.sort_by(&:taken_on)
    end

    def snapshots_taken(period_type, dates)
      snapshots.select { it.period_type == period_type.to_s && dates.cover?(it.taken_on) }.sort_by(&:taken_on)
    end

    def week_snapshots_within(period)
      snapshots.select { it.period_type == 'week' && it.period_end >= period.first && it.period_start <= period.last }.sort_by(&:taken_on)
    end

    def totals(dates)
      totals_by_date.select { |date, _| dates.cover?(date) }
    end

    def forecasts(dates)
      forecasts_by_date.select { |date, _| dates.cover?(date) }
    end
  end
end
