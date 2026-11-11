module RevenueProjections
  class CalculateCommand
    PERIOD_TYPES = %i[month week].freeze
    WEEK_START = :sunday
    BASELINE_DAYS = 84
    HOLIDAY_HISTORY_DAYS = 365

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
      RevenueProjection::Result.new(period_type:, period:, reference_at:, days: period.map { build_day(it) },
                                    factors: holiday_factors.factors, history_days: baseline.days_count)
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
      realized = realized_totals.fetch(date, 0).to_i
      factor = date < reference_date ? 0.0 : holiday_factors.factor(date) * remaining_share(date)

      RevenueProjection::Day.new(
        date:, realized_cents: realized, holiday: holidays[date],
        expected_cents: expected(date, RevenueProjection::Baseline::MEDIAN, factor),
        low_cents: expected(date, RevenueProjection::Baseline::LOW, factor),
        high_cents: expected(date, RevenueProjection::Baseline::HIGH, factor)
      )
    end

    def expected(date, percentile, factor)
      (baseline.typical(date.wday, percentile) * factor).round
    end

    def remaining_share(date)
      return 1.0 if date > reference_date

      1.0 - baseline.share_until(date.wday, (reference_at - reference_at.beginning_of_day) / 1.hour)
    end

    def documents
      tenant.billable_freights.active.not_canceled
    end

    def realized_totals
      @realized_totals ||= documents.where(issued_at: period.first.beginning_of_day..reference_at).group_by_day(:issued_at).sum(:freight_cents)
    end

    def history_start
      @history_start ||= begin
        first_issued_on = documents.minimum(:issued_at)&.to_date || reference_date

        [reference_date - HOLIDAY_HISTORY_DAYS - (RevenueProjection::HolidayFactors::NEIGHBOR_WEEKS * 7), first_issued_on].max
      end
    end

    def daily_history
      @daily_history ||= if history_start < reference_date
                           documents.group_by_day(:issued_at, range: history_start.beginning_of_day...reference_date.beginning_of_day)
                             .sum(:freight_cents).transform_values(&:to_i)
                         else
                           {}
                         end
    end

    def baseline_dates
      @baseline_dates ||= daily_history.keys.select { it >= reference_date - BASELINE_DAYS && !holidays.key?(it) }.to_set
    end

    def baseline
      @baseline ||= RevenueProjection::Baseline.new(daily_history.slice(*baseline_dates), hourly_history)
    end

    def hourly_history
      return {} if baseline_dates.empty?

      documents.where(issued_at: baseline_dates.min.beginning_of_day...reference_date.beginning_of_day)
        .group_by_hour(:issued_at).sum(:freight_cents)
        .select { |time, _cents| baseline_dates.include?(time.to_date) }
    end

    def holidays
      @holidays ||= tenant.holidays.where(date: history_start..period.last).index_by(&:date)
    end

    def holiday_factors
      @holiday_factors ||= RevenueProjection::HolidayFactors.new(holidays, daily_history)
    end
  end
end
