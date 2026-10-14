module Atua
  class ImportOverview
    MOVEMENTS_LATE_AFTER = 3.hours
    REGISTRIES_LATE_AFTER = 2.days

    ReportStatus = Data.define(:report_type, :last_succeeded_at, :late) do
      alias_method :late?, :late
    end

    TenantStatus = Data.define(:tenant, :enabled, :reports) do
      alias_method :enabled?, :enabled
    end

    def initialize(tenants)
      @tenants = tenants
    end

    def statuses
      enabled_ids = Atua.enabled_tenants.ids

      tenants.map do |tenant|
        enabled = enabled_ids.include?(tenant.id)

        TenantStatus.new(tenant:, enabled:, reports: reports(tenant, enabled))
      end
    end

    private

    attr_reader :tenants

    def reports(tenant, enabled)
      Atua::Report::TYPES.map do |report_type|
        last_succeeded_at = last_successes[[tenant.id, report_type.to_s]]

        ReportStatus.new(report_type:, last_succeeded_at:, late: enabled && late?(report_type, last_succeeded_at))
      end
    end

    def late?(report_type, last_succeeded_at)
      limit = Atua::Report::MOVEMENT_TYPES.include?(report_type) ? MOVEMENTS_LATE_AFTER : REGISTRIES_LATE_AFTER

      last_succeeded_at.nil? || last_succeeded_at < limit.ago
    end

    def last_successes
      @last_successes ||= Import.succeeded.where(tenant: tenants).group(:tenant_id, :report_type).maximum(:finished_at)
    end
  end
end
