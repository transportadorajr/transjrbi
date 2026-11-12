module RevenueProjections
  class CalculateCommand
    PERIOD_TYPES = %i[month week].freeze
    WEEK_START = :sunday

    class << self
      def call(tenant, period_type:, at: Time.current)
        new(tenant, period_type, at).call
      end
    end

    def initialize(tenant, period_type, at)
      @tenant = tenant
      @period_type = period_type.to_sym
      @at = at

      raise ArgumentError, "unknown period type: #{period_type}" unless PERIOD_TYPES.include?(@period_type)
    end

    def call
      consolidate_missing_days

      RevenueProjection::Result.new(period_type:, period:, reference_at:, days: period.map { build_day(it) }, factors: factors.to_h,
                                    history_days: forecaster.history_days(reference_date))
    end

    private

    attr_reader :tenant, :period_type, :at

    def period
      @period ||= period_type == :month ? at.to_date.all_month : at.to_date.all_week(WEEK_START)
    end

    def reference_at
      @reference_at ||= (tenant.last_synced_at || at).clamp(period.first.beginning_of_day, at)
    end

    def reference_date
      reference_at.to_date
    end

    def build_day(date)
      forecast = forecaster.forecast(date, as_of: reference_date) unless date < reference_date
      share = remaining_share(date)

      RevenueProjection::Day.new(
        date:, realized_cents: realized_totals.fetch(date, 0).to_i, holiday: holidays[date],
        expected_cents: scaled(forecast&.forecast_cents, share), low_cents: scaled(forecast&.low_cents, share),
        high_cents: scaled(forecast&.high_cents, share)
      )
    end

    def scaled(cents, share)
      ((cents || 0) * share).round
    end

    def remaining_share(date)
      return 1.0 unless date == reference_date

      1.0 - forecaster.share_until(date.wday, (reference_at - reference_at.beginning_of_day) / 1.hour, as_of: reference_date)
    end

    def documents
      tenant.billable_freights.active.not_canceled
    end

    def realized_totals
      @realized_totals ||= documents.where(issued_at: period.first.beginning_of_day..reference_at).group_by_day(:issued_at).sum(:freight_cents)
    end

    def consolidate_missing_days
      first_date = documents.minimum(:issued_at)&.to_date
      return unless first_date

      last_consolidated = tenant.revenue_projection_daily_totals.maximum(:date)
      start = last_consolidated ? last_consolidated + 1 : first_date
      ConsolidateDaysCommand.call(tenant, start...reference_date) if start < reference_date
    end

    def holidays
      @holidays ||= tenant.holidays.where(date: (reference_date - RevenueProjection::Forecaster::BASELINE_DAYS)..period.last).index_by(&:date)
    end

    def factors
      @factors ||= RevenueProjection::FactorSet.new(RevenueProjection::Factor.where(tenant:))
    end

    def forecaster
      @forecaster ||= RevenueProjection::Forecaster.new(
        tenant.revenue_projection_daily_totals.where(date: (reference_date - RevenueProjection::Forecaster::BASELINE_DAYS)...reference_date)
          .index_by(&:date),
        RevenueProjection::Calendar.new(holidays), factors
      )
    end
  end
end
