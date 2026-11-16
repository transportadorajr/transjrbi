module RevenueProjections
  class RefreshCurrentCommand
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
      snapshots.each do |snapshot|
        result = CalculateCommand.call(tenant, period_type: snapshot.period_type, at:)

        snapshot.update_columns(current_projected_cents: result.projected_cents, current_low_cents: result.low_cents,
                                current_high_cents: result.high_cents, current_reference_at: result.reference_at,
                                current_refreshed_at: at, updated_at: Time.current)
      end.size
    end

    private

    attr_reader :tenant, :at

    def snapshots
      tenant.revenue_projection_snapshots.where(taken_on: at.to_date, reconstructed: false).to_a
    end
  end
end
