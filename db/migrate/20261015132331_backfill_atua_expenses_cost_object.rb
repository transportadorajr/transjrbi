class BackfillAtuaExpensesCostObject < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE atua_expenses
      SET cost_object_type = targets.cost_object_type, cost_object_id = targets.cost_object_id, updated_at = NOW()
      FROM (
        SELECT expenses.id,
               CASE WHEN transport_documents.id IS NOT NULL THEN 'Atua::TransportDocument'
                    WHEN vehicles.id IS NOT NULL THEN 'Atua::Vehicle' END AS cost_object_type,
               COALESCE(transport_documents.id, vehicles.id) AS cost_object_id
        FROM atua_expenses expenses
        LEFT JOIN atua_transport_documents transport_documents
          ON transport_documents.tenant_id = expenses.tenant_id
         AND transport_documents.code = expenses.transport_document_code
         AND transport_documents.removed_from_atua_at IS NULL
        LEFT JOIN LATERAL (
          SELECT candidates.id
          FROM atua_vehicles candidates
          WHERE candidates.tenant_id = expenses.tenant_id AND candidates.plate = expenses.plate
          ORDER BY candidates.removed_from_atua_at IS NULL DESC, candidates.code DESC
          LIMIT 1
        ) vehicles ON TRUE
      ) targets
      WHERE atua_expenses.id = targets.id
        AND (atua_expenses.cost_object_type IS DISTINCT FROM targets.cost_object_type
             OR atua_expenses.cost_object_id IS DISTINCT FROM targets.cost_object_id)
    SQL
  end

  def down; end
end
