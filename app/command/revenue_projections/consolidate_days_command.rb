module RevenueProjections
  class ConsolidateDaysCommand
    class << self
      def call(tenant, dates)
        new(tenant, dates).call
      end
    end

    def initialize(tenant, dates)
      @tenant = tenant
      @dates = dates.to_a
    end

    def call
      return 0 if dates.none?

      RevenueProjection::DailyTotal.upsert_all(rows, unique_by: %i[tenant_id date], update_only: %i[wday day_type billed_cents documents_count
                                                                                                    hourly_cents consolidated_at])
      fill_forecast_actuals

      dates.count
    end

    private

    attr_reader :tenant, :dates

    def rows
      BuildDailyTotalsCommand.call(tenant, tenant.billable_freights, dates)
    end

    def fill_forecast_actuals
      totals = RevenueProjection::DailyTotal.arel_table

      tenant.revenue_projection_day_forecasts.where(date: dates)
        .joins("INNER JOIN #{totals.name} ON #{totals.name}.tenant_id = revenue_projection_day_forecasts.tenant_id " \
               "AND #{totals.name}.date = revenue_projection_day_forecasts.date")
        .update_all(<<~SQL.squish)
          actual_cents = #{totals.name}.billed_cents,
          day_type = #{totals.name}.day_type,
          error_ratio = CASE WHEN #{totals.name}.billed_cents > 0
                             THEN (revenue_projection_day_forecasts.forecast_cents - #{totals.name}.billed_cents)::decimal / #{totals.name}.billed_cents
                        END,
          updated_at = NOW()
        SQL
    end
  end
end
