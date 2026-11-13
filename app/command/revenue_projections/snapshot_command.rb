module RevenueProjections
  class SnapshotCommand
    UNIQUE_BY = %i[tenant_id period_type period_start taken_on].freeze
    UPDATED_COLUMNS = %i[period_end reference_at realized_cents projected_cents low_cents high_cents days reconstructed].freeze

    class << self
      def call(tenant, at: Time.current, reconstructed: false)
        new(tenant, at, reconstructed).call
      end
    end

    def initialize(tenant, at, reconstructed)
      @tenant = tenant
      @at = at
      @reconstructed = reconstructed
    end

    def call
      rows = RevenueProjection::Snapshot::PERIOD_TYPES.map { |period_type| row(period_type) }
      return RevenueProjection::Snapshot.insert_all(rows, unique_by: UNIQUE_BY).length if reconstructed

      RevenueProjection::Snapshot.upsert_all(rows, unique_by: UNIQUE_BY, update_only: UPDATED_COLUMNS).length
    end

    private

    attr_reader :tenant, :at, :reconstructed

    def row(period_type)
      result = CalculateCommand.call(tenant, period_type:, at:, factors:)
      now = Time.current

      { tenant_id: tenant.id, period_type:, period_start: result.period.first, period_end: result.period.last, taken_on: at.to_date,
        reference_at: result.reference_at, realized_cents: result.realized_cents, projected_cents: result.projected_cents,
        low_cents: result.low_cents, high_cents: result.high_cents, days: result.days.map { day_row(it) }, reconstructed:,
        created_at: now, updated_at: now }
    end

    def day_row(day)
      { date: day.date.iso8601, realized_cents: day.realized_cents, expected_cents: day.expected_cents, low_cents: day.low_cents,
        high_cents: day.high_cents }
    end

    def factors
      return unless reconstructed

      @factors ||= LearnFactorsCommand.factor_set(tenant, at:)
    end
  end
end
