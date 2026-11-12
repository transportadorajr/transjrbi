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

    def documents
      tenant.billable_freights.active.not_canceled.where(issued_at: dates.first.beginning_of_day..dates.last.end_of_day)
    end

    def hourly_totals
      @hourly_totals ||= documents.group_by_hour(:issued_at).sum(:freight_cents)
        .each_with_object(Hash.new { |hash, date| hash[date] = Array.new(RevenueProjection::DailyTotal::HOURS, 0) }) do |(time, cents), totals|
        totals[time.to_date][time.hour] += cents.to_i
      end
    end

    def documents_counts
      @documents_counts ||= documents.group_by_day(:issued_at).count
    end

    def calendar
      @calendar ||= RevenueProjection::Calendar.new(tenant.holidays.where(date: dates).index_by(&:date))
    end

    def rows
      now = Time.current

      dates.map do |date|
        hourly = hourly_totals.fetch(date) { Array.new(RevenueProjection::DailyTotal::HOURS, 0) }

        { tenant_id: tenant.id, date:, wday: date.wday, day_type: calendar.day_type(date), billed_cents: hourly.sum, hourly_cents: hourly,
          documents_count: documents_counts.fetch(date, 0), consolidated_at: now, created_at: now, updated_at: now }
      end
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
