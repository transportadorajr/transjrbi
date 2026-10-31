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
      ungrouped_customers.group_by { |customer| group_for(customer) }.except(nil).sum do |group, customers|
        tenant.atua_customers.where(id: customers.map(&:id)).update_all(customer_group_id: group.id)
      end
    end

    private

    attr_reader :tenant, :own_groups

    def ungrouped_customers
      tenant.atua_customers.without_customer_group.order(:id).to_a
    end

    def group_for(customer)
      names = [customer.name, customer.trade_name, *taker_names.fetch(customer.code, [])]

      term_groups.find { |group| group.match?(*names) } || (own_group(customer) if own_group?(customer))
    end

    def taker_names
      @taker_names ||= tenant.atua_transport_documents.where(taker_code: tenant.atua_customers.without_customer_group.select(:code))
        .taker_names_by_code
    end

    def own_group?(customer)
      recent_taker_codes.include?(customer.code) || !documents_loaded?
    end

    def documents_loaded?
      return @documents_loaded if defined?(@documents_loaded)

      @documents_loaded = tenant.atua_transport_documents.exists?
    end

    def recent_taker_codes
      @recent_taker_codes ||= tenant.atua_transport_documents.active.recently_issued.distinct.pluck(:taker_code).to_set
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
