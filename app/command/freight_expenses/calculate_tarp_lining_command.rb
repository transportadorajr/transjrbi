module FreightExpenses
  class CalculateTarpLiningCommand
    GROUP_NAME = 'MOINHO REGIO'.freeze
    RATE_CENTS = 5_500
    COMPARED_ATTRIBUTES = %i[rate_cents amount_cents].freeze

    Result = Data.define(:saved, :removed)

    class << self
      def call(tenant)
        new(tenant).call
      end

      def customer_group(tenant)
        tenant.customer_groups.activated.for_name(GROUP_NAME)
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      expected = expected_expenses
      existing = tarp_linings.index_by(&:transport_document_id)
      changed = expected.reject { |document_id, attributes| unchanged?(existing[document_id], attributes) }
      stale_document_ids = existing.keys - expected.keys

      ActiveRecord::Base.transaction do
        tarp_linings.where(transport_document_id: stale_document_ids).delete_all if stale_document_ids.any?
        save(changed) if changed.any?
      end

      Result.new(saved: changed.size, removed: stale_document_ids.size)
    end

    private

    attr_reader :tenant

    def tarp_linings
      tenant.freight_expenses.tarp_lining
    end

    def expected_expenses
      group = self.class.customer_group(tenant)
      return {} unless group

      documents(group).index_with { { rate_cents: RATE_CENTS, amount_cents: RATE_CENTS } }
    end

    def documents(group)
      tenant.atua_transport_documents.commissionable.joins(:taker)
        .where(atua_customers: { customer_group_id: group.id }).pluck(:id)
    end

    def unchanged?(expense, attributes)
      expense.present? && COMPARED_ATTRIBUTES.all? { |attribute| expense.public_send(attribute) == attributes[attribute] }
    end

    def save(changed)
      calculated_at = Time.current
      rows = changed.map do |document_id, attributes|
        attributes.merge(tenant_id: tenant.id, transport_document_id: document_id, kind_type: 'tarp_lining', calculated_at:)
      end

      FreightExpense.upsert_all(rows, unique_by: %i[transport_document_id kind_type])
    end
  end
end
