module RevenueProjections
  class BuildDailyTotalsCommand
    class << self
      def call(tenant, documents, dates)
        new(tenant, documents, dates).call
      end
    end

    def initialize(tenant, documents, dates)
      @tenant = tenant
      @documents = documents
      @dates = dates.to_a
    end

    def call
      return [] if dates.none?

      now = Time.current

      dates.map do |date|
        hourly = hourly_totals.fetch(date) { Array.new(RevenueProjection::DailyTotal::HOURS, 0) }

        { tenant_id: tenant.id, date:, wday: date.wday, day_type: calendar.day_type(date), billed_cents: hourly.sum, hourly_cents: hourly,
          documents_count: documents_counts.fetch(date, 0), consolidated_at: now, created_at: now, updated_at: now }
      end
    end

    private

    attr_reader :tenant, :documents, :dates

    def scoped_documents
      documents.active.not_canceled.where(issued_at: dates.first.beginning_of_day..dates.last.end_of_day)
    end

    def hourly_totals
      @hourly_totals ||= scoped_documents.group_by_hour(:issued_at).sum(:freight_cents)
        .each_with_object(Hash.new { |hash, date| hash[date] = Array.new(RevenueProjection::DailyTotal::HOURS, 0) }) do |(time, cents), totals|
        totals[time.to_date][time.hour] += cents.to_i
      end
    end

    def documents_counts
      @documents_counts ||= scoped_documents.group_by_day(:issued_at).count
    end

    def calendar
      @calendar ||= RevenueProjection::Calendar.new(tenant.holidays.where(date: dates.first..dates.last).index_by(&:date))
    end
  end
end
