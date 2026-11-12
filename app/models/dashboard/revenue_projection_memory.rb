module Dashboard
  class RevenueProjectionMemory
    SUMMARY_DAYS = 90
    WEEKDAY_ORDER = [1, 2, 3, 4, 5, 6, 0].freeze

    ErrorRow = Data.define(:day_type, :wday, :days, :mean_absolute_error, :bias)
    FactorRow = Data.define(:factor_type, :wday, :value, :observations_count, :learned)

    def initialize(tenant, today: Date.current)
      @tenant = tenant
      @today = today
    end

    delegate :any?, to: :forecasts

    def mean_absolute_error
      mean(forecasts.map { it.error_ratio.to_f.abs })
    end

    def bias
      mean(forecasts.map { it.error_ratio.to_f })
    end

    def error_rows
      regular_rows + other_rows
    end

    def factor_rows
      factors = ::RevenueProjection::Factor.where(tenant:).index_by { [it.factor_type.to_sym, it.wday] }
      keys = (::RevenueProjection::Factor::FACTOR_TYPES - [:weekday_bias]).map { [it, nil] } + WEEKDAY_ORDER.map { [:weekday_bias, it] }

      keys.filter_map do |factor_type, wday|
        factor = factors[[factor_type, wday]]
        FactorRow.new(factor_type:, wday:, value: factor.value.to_f, observations_count: factor.observations_count, learned: factor.learned) if factor
      end
    end

    private

    attr_reader :tenant, :today

    def forecasts
      @forecasts ||= tenant.revenue_projection_day_forecasts.with_actual.where.not(error_ratio: nil)
        .where(date: (today - SUMMARY_DAYS)...today).to_a
    end

    def regular_rows
      by_wday = forecasts.select(&:regular?).group_by(&:wday)

      WEEKDAY_ORDER.filter_map { |wday| error_row(:regular, wday, by_wday[wday]) }
    end

    def other_rows
      by_type = forecasts.reject(&:regular?).group_by { it.day_type.to_sym }

      (::RevenueProjection::DailyTotal::DAY_TYPES - [:regular]).filter_map { |day_type| error_row(day_type, nil, by_type[day_type]) }
    end

    def error_row(day_type, wday, rows)
      return if rows.blank?

      errors = rows.map { it.error_ratio.to_f }
      ErrorRow.new(day_type:, wday:, days: rows.size, mean_absolute_error: mean(errors.map(&:abs)), bias: mean(errors))
    end

    def mean(values)
      values.sum / values.size if values.any?
    end
  end
end
