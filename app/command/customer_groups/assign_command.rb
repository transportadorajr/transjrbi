module CustomerGroups
  class AssignCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
      @own_groups = {}
    end

    def call
      ungrouped_customers.group_by { |customer| group_for(customer) }.sum do |group, customers|
        tenant.atua_customers.where(id: customers.map(&:id)).update_all(customer_group_id: group.id)
      end
    end

    private

    attr_reader :tenant, :own_groups

    def ungrouped_customers
      tenant.atua_customers.without_customer_group.order(:id).to_a
    end

    def group_for(customer)
      term_groups.find { |group| group.match?(customer.name, customer.trade_name) } || own_group(customer)
    end

    def term_groups
      @term_groups ||= tenant.customer_groups.with_terms.order(:id).to_a
    end

    def own_group(customer)
      name = own_group_name(customer)

      own_groups[name] ||= tenant.customer_groups.create_with(activated_at: Time.current).find_or_create_by!(name:)
    end

    def own_group_name(customer)
      customer.name.to_s.squish.presence || customer.trade_name.to_s.squish.presence ||
        I18n.t('customer_groups.unnamed', code: customer.code)
    end
  end
end
