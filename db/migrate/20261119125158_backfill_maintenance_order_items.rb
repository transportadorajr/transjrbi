class BackfillMaintenanceOrderItems < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO maintenance_order_items
        (tenant_id, maintenance_order_id, itemizable_type, itemizable_id, description, notes, total_cents, position, created_at, updated_at)
      SELECT legacy.tenant_id, legacy.maintenance_order_id, legacy.itemizable_type, legacy.itemizable_id, legacy.description,
             legacy.notes, legacy.total_cents,
             ROW_NUMBER() OVER (PARTITION BY legacy.maintenance_order_id ORDER BY legacy.kind, legacy.itemizable_id),
             legacy.created_at, legacy.updated_at
      FROM (
        SELECT 1 AS kind, tenant_id, maintenance_order_id, 'MaintenanceOrderPart' AS itemizable_type, id AS itemizable_id,
               description, notes, total_cents, created_at, updated_at
        FROM maintenance_order_parts
        UNION ALL
        SELECT 2, tenant_id, maintenance_order_id, 'MaintenanceOrderService', id,
               description, notes, COALESCE(approved_cents, quoted_cents, 0), created_at, updated_at
        FROM maintenance_order_services
      ) legacy
      WHERE NOT EXISTS (
        SELECT 1 FROM maintenance_order_items items
        WHERE items.itemizable_type = legacy.itemizable_type AND items.itemizable_id = legacy.itemizable_id
      )
    SQL
  end

  def down
    execute 'DELETE FROM maintenance_order_items'
  end
end
