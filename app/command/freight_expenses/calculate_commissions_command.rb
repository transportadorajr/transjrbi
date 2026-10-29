module FreightExpenses
  class CalculateCommissionsCommand
    COMPARED_ATTRIBUTES = %i[commission_rule_id base_cents icms_cents percentage amount_cents].freeze

    Result = Data.define(:saved, :removed)

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      expected = expected_expenses
      existing = commissions.index_by(&:transport_document_id)
      changed = expected.reject { |document_id, attributes| unchanged?(existing[document_id], attributes) }
      stale_document_ids = existing.keys - expected.keys

      ActiveRecord::Base.transaction do
        commissions.where(transport_document_id: stale_document_ids).delete_all if stale_document_ids.any?
        save(changed) if changed.any?
      end

      Result.new(saved: changed.size, removed: stale_document_ids.size)
    end

    private

    attr_reader :tenant

    def commissions
      tenant.freight_expenses.commission
    end

    def expected_expenses
      rules = tenant.commission_rules.activated.to_a.group_by(&:customer_group_id)
      return {} if rules.empty?

      documents.each_with_object({}) do |(document_id, freight_cents, icms_cents, state, city, group_id, recipient_name, recipient_city), expenses|
        rule = CommissionRule.for_destination(rules.fetch(group_id, []), state, city, recipient_city:, recipient_name:)
        expenses[document_id] = expense_attributes(rule, freight_cents, icms_cents) if rule
      end
    end

    def documents
      CommissionRule.covered_documents(tenant).joins(recipient_join)
        .pluck(:id, :freight_cents, :icms_cents, :destination_state, :destination_city, Atua::Customer.arel_table[:customer_group_id],
               :recipient_name, recipients[:city])
    end

    def recipient_join
      documents_table = Atua::TransportDocument.arel_table

      documents_table.join(recipients, Arel::Nodes::OuterJoin)
        .on(recipients[:tenant_id].eq(documents_table[:tenant_id]).and(recipients[:code].eq(documents_table[:recipient_code])))
        .join_sources
    end

    def recipients
      @recipients ||= Atua::Customer.arel_table.alias('recipients')
    end

    def expense_attributes(rule, freight_cents, icms_cents)
      deducted_icms_cents = rule.deducted_icms_cents(icms_cents)
      base_cents = freight_cents.to_i - deducted_icms_cents

      {
        commission_rule_id: rule.id,
        base_cents:,
        icms_cents: deducted_icms_cents,
        percentage: rule.percentage,
        amount_cents: rule.amount_cents(base_cents),
      }
    end

    def unchanged?(expense, attributes)
      expense.present? && COMPARED_ATTRIBUTES.all? { |attribute| expense.public_send(attribute) == attributes[attribute] }
    end

    def save(changed)
      calculated_at = Time.current
      rows = changed.map do |document_id, attributes|
        attributes.merge(tenant_id: tenant.id, transport_document_id: document_id, kind_type: 'commission', calculated_at:)
      end

      FreightExpense.upsert_all(rows, unique_by: %i[transport_document_id kind_type])
    end
  end
end
