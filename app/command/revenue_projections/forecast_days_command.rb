module RevenueProjections
  class ForecastDaysCommand
    class << self
      def call(tenant, dates, backfilled: false)
        new(tenant, dates, backfilled).call
      end
    end

    def initialize(tenant, dates, backfilled)
      @tenant = tenant
      @dates = dates.to_a
      @backfilled = backfilled
    end

    def call
      rows = dates.filter_map { |date| row(forecaster.forecast(date)) }
      return 0 if rows.empty?

      RevenueProjection::DayForecast.insert_all(rows, unique_by: %i[tenant_id date]).length
    end

    private

    attr_reader :tenant, :dates, :backfilled

    def forecaster
      @forecaster ||= begin
        daily_totals = tenant.revenue_projection_daily_totals
          .where(date: (dates.first - RevenueProjection::Forecaster::BASELINE_DAYS)...dates.last).index_by(&:date)
        calendar = RevenueProjection::Calendar.new(tenant.holidays.where(date: (dates.first - RevenueProjection::Forecaster::BASELINE_DAYS)..dates.last)
                                                     .index_by(&:date))

        RevenueProjection::Forecaster.new(daily_totals, calendar, RevenueProjection::FactorSet.new(RevenueProjection::Factor.where(tenant:)))
      end
    end

    def row(forecast)
      return unless forecast

      now = Time.current

      { tenant_id: tenant.id, date: forecast.date, wday: forecast.date.wday, day_type: forecast.day_type, typical_cents: forecast.typical_cents,
        factor: forecast.factor, forecast_cents: forecast.forecast_cents, low_cents: forecast.low_cents, high_cents: forecast.high_cents,
        backfilled:, forecast_at: now, created_at: now, updated_at: now }
    end
  end
end
