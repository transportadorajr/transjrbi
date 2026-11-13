module Dashboard
  class RevenueProjectionToday
    def initialize(tenant, today: Date.current, memory: ::RevenueProjection::StoredMemory.new(tenant), documents: tenant.billable_freights)
      @tenant = tenant
      @today = today
      @memory = memory
      @documents = documents
    end

    attr_reader :today

    def period_type
      'today'
    end

    def any?
      forecast.present? || snapshots.any?
    end

    def forecast_cents
      forecast&.forecast_cents
    end

    def day_type
      forecast&.day_type || 'regular'
    end

    def billed_cents
      documents.sum(:freight_cents)
    end

    delegate :count, to: :documents, prefix: true

    def difference_cents
      billed_cents - forecast_cents if forecast_cents
    end

    def difference_ratio
      difference_cents.to_f / forecast_cents if forecast_cents&.positive?
    end

    def month_snapshot
      snapshots['month']
    end

    def week_snapshot
      snapshots['week']
    end

    def last_synced_at
      @last_synced_at ||= tenant.last_synced_at
    end

    private

    attr_reader :tenant, :memory

    def forecast
      return @forecast if defined?(@forecast)

      @forecast = memory.forecasts(today..today)[today]
    end

    def snapshots
      @snapshots ||= ::RevenueProjection::Snapshot::PERIOD_TYPES.filter_map { memory.snapshots_taken(it, today..today).first }.index_by(&:period_type)
    end

    def documents
      @documents.active.not_canceled.where(issued_at: today.all_day)
    end
  end
end
