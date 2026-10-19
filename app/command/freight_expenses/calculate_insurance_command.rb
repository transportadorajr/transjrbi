module FreightExpenses
  class CalculateInsuranceCommand
    COMPARED_ATTRIBUTES = %i[insurance_rate_id base_cents percentage iof_percentage iof_cents amount_cents].freeze

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
      existing = insurances.index_by(&:transport_document_id)
      changed = expected.reject { |document_id, attributes| unchanged?(existing[document_id], attributes) }
      stale_document_ids = existing.keys - expected.keys

      ActiveRecord::Base.transaction do
        insurances.where(transport_document_id: stale_document_ids).delete_all if stale_document_ids.any?
        save(changed) if changed.any?
      end

      Result.new(saved: changed.size, removed: stale_document_ids.size)
    end

    private

    attr_reader :tenant

    def insurances
      tenant.freight_expenses.insurance
    end

    def expected_expenses
      rates = tenant.insurance_rates.order(:valid_from).to_a
      return {} if rates.empty?

      documents.each_with_object({}) do |(document_id, issued_at, goods_value_cents, freight_cents, state), expenses|
        next if issued_at.nil?

        rate = InsuranceRate.for_date(rates, issued_at.in_time_zone.to_date)
        expenses[document_id] = expense_attributes(rate, goods_value_cents.to_i + freight_cents.to_i, state)
      end
    end

    def documents
      tenant.atua_transport_documents.commissionable
        .pluck(:id, :issued_at, :goods_value_cents, :freight_cents, :destination_state)
    end

    def expense_attributes(rate, base_cents, state)
      insurance_cents = rate.insurance_cents(base_cents)
      iof_percentage = CommissionRule.foreign_destination?(state) ? rate.iof_percentage : 0
      iof_cents = CommissionRule.foreign_destination?(state) ? rate.iof_cents(insurance_cents) : 0

      {
        insurance_rate_id: rate.id,
        base_cents:,
        percentage: rate.insurance_percentage,
        iof_percentage:,
        iof_cents:,
        amount_cents: insurance_cents + iof_cents,
      }
    end

    def unchanged?(expense, attributes)
      expense.present? && COMPARED_ATTRIBUTES.all? { |attribute| expense.public_send(attribute) == attributes[attribute] }
    end

    def save(changed)
      calculated_at = Time.current
      rows = changed.map do |document_id, attributes|
        attributes.merge(tenant_id: tenant.id, transport_document_id: document_id, kind_type: 'insurance', calculated_at:)
      end

      FreightExpense.upsert_all(rows, unique_by: %i[transport_document_id kind_type])
    end
  end
end
