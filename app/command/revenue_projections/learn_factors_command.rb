module RevenueProjections
  class LearnFactorsCommand
    WINDOWS = { weekday_bias: 56, month_end: 183 }.freeze
    HOLIDAY_WINDOW = 365

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
      rows = bias_rows + day_type_rows
      RevenueProjection::Factor.upsert_all(rows, unique_by: %i[tenant_id factor_type wday],
                                                 update_only: %i[value observations_count learned learned_at])

      rows.size
    end

    private

    attr_reader :tenant, :at

    def forecasts(days)
      tenant.revenue_projection_day_forecasts.with_actual.where(date: (at.to_date - days)...at.to_date).where(typical_cents: 1..)
    end

    def biases
      @biases ||= forecasts(WINDOWS[:weekday_bias]).regular.group_by(&:wday).transform_values do |rows|
        rows.map { it.actual_cents / it.typical_cents.to_f }
      end
    end

    def bias_rows
      (0..6).map { |wday| factor_row(:weekday_bias, biases.fetch(wday, []), wday:) }
    end

    def day_type_rows
      (RevenueProjection::Factor::FACTOR_TYPES - [:weekday_bias]).map do |factor_type|
        ratios = forecasts(WINDOWS.fetch(factor_type, HOLIDAY_WINDOW)).where(day_type: factor_type).map do |forecast|
          forecast.actual_cents / (forecast.typical_cents * learned_bias(forecast.wday))
        end

        factor_row(factor_type, ratios)
      end
    end

    def learned_bias(wday)
      ratios = biases.fetch(wday, [])
      ratios.size >= RevenueProjection::Factor::MIN_OBSERVATIONS[:weekday_bias] ? median(ratios).clamp(RevenueProjection::Factor::LIMITS[:weekday_bias]) : 1.0
    end

    def factor_row(factor_type, ratios, wday: nil)
      learned = ratios.size >= RevenueProjection::Factor::MIN_OBSERVATIONS.fetch(factor_type)
      value = learned ? median(ratios).clamp(RevenueProjection::Factor::LIMITS.fetch(factor_type)) : RevenueProjection::Factor::DEFAULTS.fetch(factor_type)
      now = Time.current

      { tenant_id: tenant.id, factor_type:, wday:, value: value.round(4), observations_count: ratios.size, learned:, learned_at: at,
        created_at: now, updated_at: now }
    end

    def median(values)
      sorted = values.sort
      middle = sorted.size / 2

      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end
  end
end
