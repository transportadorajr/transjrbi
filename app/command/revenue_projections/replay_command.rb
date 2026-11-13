module RevenueProjections
  class ReplayCommand
    class << self
      def call(tenant, documents, period, today: Date.current)
        new(tenant, documents, period, today).call
      end
    end

    def initialize(tenant, documents, period, today)
      @tenant = tenant
      @documents = documents
      @period = period
      @today = today
    end

    def call
      RevenueProjection::Replay.new(totals_by_date: totals, forecasts_by_date: forecasts, snapshots:)
    end

    private

    attr_reader :tenant, :documents, :period, :today

    def first_morning
      period.first.beginning_of_week(CalculateCommand::WEEK_START)
    end

    def last_morning
      [period.last, today].min
    end

    def mornings
      first_morning..last_morning
    end

    def totals
      @totals ||= BuildDailyTotalsCommand.call(tenant, documents, (first_morning - RevenueProjection::Forecaster::BASELINE_DAYS)..[period.last, today - 1].min)
        .map { RevenueProjection::DailyTotal.new(it) }.index_by(&:date)
    end

    def forecasts
      period.select { it <= last_morning }.filter_map { forecast(it) }.index_by(&:date)
    end

    def forecast(date)
      forecast = RevenueProjection::Forecaster.new(totals, calendar, factor_set(date)).forecast(date)
      return unless forecast

      RevenueProjection::DayForecast.new(tenant_id: tenant.id, date:, wday: date.wday, backfilled: true,
                                         **forecast.to_h.slice(:day_type, :typical_cents, :factor, :forecast_cents, :low_cents, :high_cents))
    end

    def snapshots
      mornings.flat_map { |date| RevenueProjection::Snapshot::PERIOD_TYPES.map { snapshot(it, date) } }
    end

    def snapshot(period_type, date)
      at = date.in_time_zone.change(hour: RefreshMemoryCommand::SNAPSHOT_HOUR)
      result = CalculateCommand.call(tenant, period_type:, at:, factors: factor_set(date), documents:, daily_totals: totals)

      RevenueProjection::Snapshot.new(
        tenant_id: tenant.id, period_type:, period_start: result.period.first, period_end: result.period.last, taken_on: date,
        reference_at: result.reference_at, realized_cents: result.realized_cents, projected_cents: result.projected_cents, low_cents: result.low_cents,
        high_cents: result.high_cents, days: result.days.map { day_row(it) }, reconstructed: true
      )
    end

    def day_row(day)
      { 'date' => day.date.iso8601, 'realized_cents' => day.realized_cents, 'expected_cents' => day.expected_cents, 'low_cents' => day.low_cents,
        'high_cents' => day.high_cents }
    end

    def factor_set(date)
      @factor_sets ||= {}
      @factor_sets[date] ||= LearnFactorsCommand.factor_set(tenant, at: date.in_time_zone.change(hour: RefreshMemoryCommand::SNAPSHOT_HOUR))
    end

    def calendar
      @calendar ||= RevenueProjection::Calendar.new(
        tenant.holidays.where(date: (first_morning - RevenueProjection::Forecaster::BASELINE_DAYS)..period.last).index_by(&:date),
      )
    end
  end
end
