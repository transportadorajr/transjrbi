module CustomerGroups
  class UnifyCommand
    class << self
      def call(tenant, name, terms)
        new(tenant, name, terms).call
      end
    end

    def initialize(tenant, name, terms)
      @tenant = tenant
      @name = name
      @terms = terms
    end

    def call
      group = nil
      moved = 0

      ActiveRecord::Base.transaction do
        group = find_or_create_group
        moved = move_customers(group)
        group.update!(activated_at: Time.current) unless group.activated?
      end

      FreightExpenses::CalculateJob.perform_later(tenant.id) if moved.positive?

      group
    end

    private

    attr_reader :tenant, :name, :terms

    def find_or_create_group
      group = tenant.customer_groups.create_with(activated_at: Time.current).find_or_create_by!(name:)
      missing_terms = terms - group.terms
      group.update!(terms: group.terms + missing_terms) if missing_terms.any?
      group
    end

    def move_customers(group)
      customers = tenant.atua_customers
      ids = customers.without_customer_group.or(customers.where.not(customer_group_id: group.id)).order(:id).to_a
        .select { |customer| matches?(customer) }.map(&:id)

      tenant.atua_customers.where(id: ids).update_all(customer_group_id: group.id, updated_at: Time.current)
    end

    def matches?(customer)
      names = [customer.name, customer.trade_name].map { |value| CustomerGroup.compact(value) }.compact_blank
      compacted_terms.any? { |term| names.any? { |customer_name| customer_name.include?(term) } }
    end

    def compacted_terms
      @compacted_terms ||= terms.map { |term| CustomerGroup.compact(term) }.compact_blank
    end
  end
end
