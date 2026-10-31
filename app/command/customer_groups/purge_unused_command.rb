module CustomerGroups
  class PurgeUnusedCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      return 0 unless tenant.atua_transport_documents.exists?

      CustomerGroup.transaction do
        group_ids = unused_groups.pluck(:id)
        tenant.atua_customers.where(customer_group_id: group_ids).update_all(customer_group_id: nil)
        tenant.customer_groups.where(id: group_ids).delete_all
      end
    end

    private

    attr_reader :tenant

    def unused_groups
      tenant.customer_groups.where(terms: [], id: tenant.atua_customers.where.not(customer_group_id: nil).select(:customer_group_id))
        .where.not(id: tenant.atua_customers.where(code: recent_taker_codes).where.not(customer_group_id: nil).select(:customer_group_id))
        .where.not(id: tenant.commission_rules.select(:customer_group_id))
        .where.not(id: tenant.tonnage_rates.select(:customer_group_id))
    end

    def recent_taker_codes
      tenant.atua_transport_documents.active.recently_issued.where.not(taker_code: nil).select(:taker_code)
    end
  end
end
