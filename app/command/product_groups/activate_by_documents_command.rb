module ProductGroups
  class ActivateByDocumentsCommand
    class << self
      def call(tenant, period)
        new(tenant, period).call
      end
    end

    def initialize(tenant, period)
      @tenant = tenant
      @period = period
    end

    def call
      ProductGroup.transaction do
        toggle(tenant.product_groups.nested, used_subgroup_ids)
        toggle(tenant.product_groups.groups, tenant.product_groups.where(id: used_subgroup_ids).select(:parent_id))
        AssignCommand.call(tenant)
      end

      tenant.product_groups.activated
    end

    private

    attr_reader :tenant, :period

    def used_subgroup_ids
      @used_subgroup_ids ||= tenant.product_groups.nested.select { |subgroup| subgroup.compacted_product_names.intersect?(used_product_names) }
        .map(&:id)
    end

    def used_product_names
      @used_product_names ||= tenant.atua_transport_documents.not_canceled.where(issued_at: period).where.not(product_name: nil)
        .distinct.pluck(:product_name).map { |product_name| ProductGroup.compact(product_name) }
    end

    def toggle(product_groups, used_ids)
      product_groups.where(id: used_ids).not_activated.update_all(activated_at: Time.current, updated_at: Time.current)
      product_groups.where.not(id: used_ids).activated.update_all(activated_at: nil, updated_at: Time.current)
    end
  end
end
