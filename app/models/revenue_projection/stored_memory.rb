module RevenueProjection
  class StoredMemory
    def initialize(tenant)
      @tenant = tenant
    end

    def recalculated?
      false
    end

    def snapshots_of(period_type, period_start)
      tenant.revenue_projection_snapshots.where(period_type:, period_start:).order(:taken_on).to_a
    end

    def snapshots_taken(period_type, dates)
      tenant.revenue_projection_snapshots.where(period_type:, taken_on: dates).order(:taken_on).to_a
    end

    def week_snapshots_within(period)
      tenant.revenue_projection_snapshots.week.where(period_end: period.first.., period_start: ..period.last).order(:taken_on).to_a
    end

    def totals(dates)
      tenant.revenue_projection_daily_totals.where(date: dates).index_by(&:date)
    end

    def forecasts(dates)
      tenant.revenue_projection_day_forecasts.where(date: dates).index_by(&:date)
    end

    private

    attr_reader :tenant
  end
end
