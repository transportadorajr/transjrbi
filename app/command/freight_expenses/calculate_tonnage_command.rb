module FreightExpenses
  class CalculateTonnageCommand
    COMPARED_ATTRIBUTES = %i[tonnage_rate_id weight_tons rate_cents amount_cents].freeze

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
      existing = tonnages.index_by(&:transport_document_id)
      changed = expected.reject { |document_id, attributes| unchanged?(existing[document_id], attributes) }
      stale_document_ids = existing.keys - expected.keys

      ActiveRecord::Base.transaction do
        tonnages.where(transport_document_id: stale_document_ids).delete_all if stale_document_ids.any?
        save(changed) if changed.any?
      end

      Result.new(saved: changed.size, removed: stale_document_ids.size)
    end

    private

    attr_reader :tenant

    def tonnages
      tenant.freight_expenses.tonnage
    end

    def expected_expenses
      rates = tenant.tonnage_rates.activated.to_a.group_by(&:series_key)
      return {} if rates.empty?

      documents.each_with_object({}) do |(document_id, issued_at, city, state, weight_tons, weight_kg, group_id), expenses|
        weight = TonnageRate.weight_in_tons(weight_tons, weight_kg)
        candidates = rates[[group_id, *TonnageRate.origin_key(city, state)]]
        next if weight.nil? || candidates.nil? || issued_at.nil?

        expenses[document_id] = expense_attributes(TonnageRate.for_month(candidates, issued_at.to_date.beginning_of_month), weight)
      end
    end

    def documents
      TonnageRate.covered_documents(tenant)
        .pluck(:id, :issued_at, :origin_city, :origin_state, :weight_tons, :weight_kg, Atua::Customer.arel_table[:customer_group_id])
    end

    def expense_attributes(rate, weight)
      { tonnage_rate_id: rate.id, weight_tons: weight, rate_cents: rate.rate_cents, amount_cents: rate.amount_cents(weight) }
    end

    def unchanged?(expense, attributes)
      expense.present? && COMPARED_ATTRIBUTES.all? { |attribute| expense.public_send(attribute) == attributes[attribute] }
    end

    def save(changed)
      calculated_at = Time.current
      rows = changed.map do |document_id, attributes|
        attributes.merge(tenant_id: tenant.id, transport_document_id: document_id, kind_type: 'tonnage', calculated_at:)
      end

      FreightExpense.upsert_all(rows, unique_by: %i[transport_document_id kind_type])
    end
  end
end
