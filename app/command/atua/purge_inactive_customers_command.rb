module Atua
  class PurgeInactiveCustomersCommand
    PARTY_COLUMNS = %i[sender_code recipient_code payer_code taker_code consignee_code].freeze

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

      Customer.transaction do
        customers = tenant.atua_customers.where.not(code: active_codes)
        group_ids = customers.where.not(customer_group_id: nil).distinct.pluck(:customer_group_id)
        removed = customers.delete_all
        empty_groups(group_ids).delete_all

        removed
      end
    end

    private

    attr_reader :tenant

    def active_codes
      documents = tenant.atua_transport_documents.active.recently_issued

      PARTY_COLUMNS.flat_map { |column| documents.distinct.pluck(column) }.compact.uniq
    end

    def empty_groups(group_ids)
      tenant.customer_groups.where(id: group_ids, terms: [])
        .where.not(id: tenant.atua_customers.where.not(customer_group_id: nil).select(:customer_group_id))
        .where.not(id: tenant.commission_rules.select(:customer_group_id))
        .where.not(id: tenant.tonnage_rates.select(:customer_group_id))
    end
  end
end
