module FreightExpenses
  class CalculateFuelCommand
    COMPARED_ATTRIBUTES = %i[truck_group_id base_cents percentage amount_cents].freeze

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
      existing = fuels.index_by(&:transport_document_id)
      changed = expected.reject { |document_id, attributes| unchanged?(existing[document_id], attributes) }
      stale_document_ids = existing.keys - expected.keys

      ActiveRecord::Base.transaction do
        fuels.where(transport_document_id: stale_document_ids).delete_all if stale_document_ids.any?
        save(changed) if changed.any?
      end

      Result.new(saved: changed.size, removed: stale_document_ids.size)
    end

    private

    attr_reader :tenant

    def fuels
      tenant.freight_expenses.fuel
    end

    def expected_expenses
      truck_groups = tenant.truck_groups.activated.to_a
      fueled_groups = truck_groups.select { |truck_group| truck_group.fuel_percentage.positive? }
      return {} if fueled_groups.empty?

      documents(fueled_groups).each_with_object({}) do |(document_id, plate, axles, freight_cents), expenses|
        truck_group = TruckGroup.for_document(truck_groups, plate:, axles:)
        amount_cents = truck_group&.fuel_cents(freight_cents) || 0
        next unless amount_cents.positive?

        expenses[document_id] = { truck_group_id: truck_group.id, base_cents: freight_cents, percentage: truck_group.fuel_percentage,
                                  amount_cents: }
      end
    end

    def documents(fueled_groups)
      documents = tenant.atua_transport_documents.commissionable
      documents = of_groups(documents, fueled_groups) if fueled_groups.none?(&:remaining_axles?)
      documents.pluck(:id, :plate, :axles, :freight_cents)
    end

    def of_groups(documents, truck_groups)
      documents.where(axles: truck_groups.flat_map(&:axles)).or(documents.where(plate: truck_groups.flat_map(&:plates)))
    end

    def unchanged?(expense, attributes)
      expense.present? && COMPARED_ATTRIBUTES.all? { |attribute| expense.public_send(attribute) == attributes[attribute] }
    end

    def save(changed)
      calculated_at = Time.current
      rows = changed.map do |document_id, attributes|
        attributes.merge(tenant_id: tenant.id, transport_document_id: document_id, kind_type: 'fuel', calculated_at:)
      end

      FreightExpense.upsert_all(rows, unique_by: %i[transport_document_id kind_type])
    end
  end
end
