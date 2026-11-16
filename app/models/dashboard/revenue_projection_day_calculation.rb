module Dashboard
  class RevenueProjectionDayCalculation
    attr_reader :date

    delegate :day_type, :typical_cents, :factor, :forecast_cents, :low_cents, :high_cents, to: :forecast, allow_nil: true

    def initialize(tenant, date, memory: ::RevenueProjection::StoredMemory.new(tenant))
      @tenant = tenant
      @date = date
      @memory = memory
    end

    def any?
      forecast.present?
    end

    def window
      (date - ::RevenueProjection::Forecaster::BASELINE_DAYS)...date
    end

    def history_days
      @history_days ||= memory.totals(window).values
        .select { it.date.wday == date.wday && calendar.day_type(it.date) == :regular }
        .sort_by(&:date)
    end

    private

    attr_reader :tenant, :memory

    def forecast
      return @forecast if defined?(@forecast)

      @forecast = memory.forecasts(date..date)[date]
    end

    def calendar
      @calendar ||= ::RevenueProjection::Calendar.new(tenant.holidays.where(date: window).index_by(&:date))
    end
  end
end
