module CustomerGroups
  class RegroupCommand
    class << self
      def call(customer_group)
        new(customer_group).call
      end
    end

    def initialize(customer_group)
      @customer_group = customer_group
    end

    def call
      customers = movable_customers.select { |customer| customer_group.match?(customer.name, customer.trade_name) }
      previous_group_ids = customers.filter_map(&:customer_group_id).uniq

      ActiveRecord::Base.transaction do
        tenant.atua_customers.where(id: customers.map(&:id)).update_all(customer_group_id: customer_group.id)
        empty_groups(previous_group_ids).delete_all
      end

      customers.size
    end

    private

    attr_reader :customer_group

    delegate :tenant, to: :customer_group

    def movable_customers
      return [] if customer_group.terms.empty?

      tenant.atua_customers.without_customer_group.or(tenant.atua_customers.where(customer_group_id: groups_without_terms))
        .order(:id).to_a
    end

    def groups_without_terms
      tenant.customer_groups.where(terms: []).where.not(id: customer_group.id).select(:id)
    end

    def empty_groups(group_ids)
      tenant.customer_groups.where(id: group_ids, terms: [])
        .where.not(id: tenant.atua_customers.where(customer_group_id: group_ids).select(:customer_group_id))
    end
  end
end
