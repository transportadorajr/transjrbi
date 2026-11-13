module RevenueProjections
  class RefreshMemoryCommand
    RECONSOLIDATE_DAYS = 35
    BACKFILL_WARMUP_DAYS = 28
    BACKFILL_SLICE_DAYS = 7
    SNAPSHOT_HOUR = 6
    RECONSTRUCTED_MONTHS = 1

    class << self
      def call(tenant, at: Time.current)
        new(tenant, at).call
      end
    end

    def initialize(tenant, at)
      @tenant = tenant
      @at = at
    end

    def call
      return unless first_date && first_date < today

      ConsolidateDaysCommand.call(tenant, consolidation_start...today)
      refresh_day_types
      backfill_forecasts
      LearnFactorsCommand.call(tenant, at:)
      ForecastDaysCommand.call(tenant, today..today)
      reconstruct_snapshots
      SnapshotCommand.call(tenant, at:)
    end

    private

    attr_reader :tenant, :at

    def today
      at.to_date
    end

    def first_date
      @first_date ||= tenant.billable_freights.active.not_canceled.minimum(:issued_at)&.to_date
    end

    def consolidation_start
      last_consolidated = tenant.revenue_projection_daily_totals.maximum(:date)
      return first_date unless last_consolidated

      [last_consolidated + 1, today - RECONSOLIDATE_DAYS].min.clamp(first_date, today)
    end

    def refresh_day_types
      calendar = RevenueProjection::Calendar.new(tenant.holidays.where(date: first_date..).index_by(&:date))
      totals = tenant.revenue_projection_daily_totals

      totals.pluck(:date).group_by { calendar.day_type(it) }.each do |day_type, dates|
        totals.where(date: dates).where.not(day_type:).update_all(day_type:, updated_at: Time.current)
        tenant.revenue_projection_day_forecasts.where(date: dates).where.not(day_type:).update_all(day_type:, updated_at: Time.current)
      end
    end

    def reconstruct_snapshots
      dates = [today.beginning_of_month.months_ago(RECONSTRUCTED_MONTHS), first_date].max...today
      taken = tenant.revenue_projection_snapshots.where(taken_on: dates).group(:taken_on).count

      dates.each do |date|
        next if taken.fetch(date, 0) == RevenueProjection::Snapshot::PERIOD_TYPES.size

        SnapshotCommand.call(tenant, at: date.in_time_zone.change(hour: SNAPSHOT_HOUR), reconstructed: true)
      end
    end

    def backfill_forecasts
      start = [tenant.revenue_projection_day_forecasts.maximum(:date)&.next_day, first_date + BACKFILL_WARMUP_DAYS].compact.max
      return if start >= today

      (start...today).each_slice(BACKFILL_SLICE_DAYS) do |dates|
        LearnFactorsCommand.call(tenant, at: dates.first.in_time_zone)
        ForecastDaysCommand.call(tenant, dates.first..dates.last, backfilled: true)
        ConsolidateDaysCommand.call(tenant, dates.first..dates.last)
      end
    end
  end
end
