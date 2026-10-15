module Atua
  class LinkExpensesCommand
    SQL = <<~SQL.squish.freeze
      UPDATE atua_expenses
      SET cost_object_type = targets.cost_object_type, cost_object_id = targets.cost_object_id, updated_at = NOW()
      FROM (
        SELECT expenses.id,
               CASE WHEN COALESCE(documents_by_code.id, documents_by_number.id) IS NOT NULL THEN :transport_document_type
                    WHEN vehicles.id IS NOT NULL THEN :vehicle_type END AS cost_object_type,
               COALESCE(documents_by_code.id, documents_by_number.id, vehicles.id) AS cost_object_id
        FROM atua_expenses expenses
        LEFT JOIN atua_transport_documents documents_by_code
          ON documents_by_code.tenant_id = expenses.tenant_id
         AND documents_by_code.code = expenses.transport_document_code
         AND documents_by_code.removed_from_atua_at IS NULL
        LEFT JOIN LATERAL (
          SELECT candidates.id
          FROM atua_transport_documents candidates
          WHERE expenses.transport_document_code IS NULL
            AND candidates.tenant_id = expenses.tenant_id
            AND candidates.number = expenses.transport_document_number
            AND (expenses.transport_document_series IS NULL OR candidates.series = expenses.transport_document_series)
            AND candidates.removed_from_atua_at IS NULL
          ORDER BY candidates.document_kind = :transport_document_kind DESC NULLS LAST,
                   candidates.canceled_at IS NULL DESC,
                   candidates.plate IS NOT DISTINCT FROM expenses.plate DESC,
                   candidates.issued_at DESC NULLS LAST,
                   candidates.code DESC
          LIMIT 1
        ) documents_by_number ON TRUE
        LEFT JOIN LATERAL (
          SELECT candidates.id
          FROM atua_vehicles candidates
          WHERE candidates.tenant_id = expenses.tenant_id AND candidates.plate = expenses.plate
          ORDER BY candidates.removed_from_atua_at IS NULL DESC, candidates.code DESC
          LIMIT 1
        ) vehicles ON TRUE
        WHERE expenses.tenant_id = :tenant_id
      ) targets
      WHERE atua_expenses.id = targets.id
        AND (atua_expenses.cost_object_type IS DISTINCT FROM targets.cost_object_type
             OR atua_expenses.cost_object_id IS DISTINCT FROM targets.cost_object_id)
    SQL

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      Expense.connection.exec_update(Expense.sanitize_sql_array([SQL, binds]))
    end

    private

    attr_reader :tenant

    def binds
      {
        tenant_id: tenant.id,
        transport_document_type: Expense::ALLOCATION_TYPES['freight'],
        transport_document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CTRC'],
        vehicle_type: Expense::ALLOCATION_TYPES['vehicle'],
      }
    end
  end
end
