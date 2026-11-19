module MaintenanceOrders
  class SyncItemsCommand
    LEGACY_ITEMS_SQL = <<~SQL.squish.freeze
      SELECT 1 AS kind, tenant_id, maintenance_order_id, 'MaintenanceOrderPart' AS itemizable_type, id AS itemizable_id,
             description, notes, total_cents, created_at, updated_at
      FROM maintenance_order_parts
      UNION ALL
      SELECT 2, tenant_id, maintenance_order_id, 'MaintenanceOrderService', id,
             description, notes, COALESCE(approved_cents, quoted_cents, 0), created_at, updated_at
      FROM maintenance_order_services
    SQL

    DELETE_ORPHANS_SQL = <<~SQL.squish.freeze
      DELETE FROM maintenance_order_items items
      WHERE NOT EXISTS (SELECT 1 FROM (#{LEGACY_ITEMS_SQL}) legacy
                        WHERE legacy.itemizable_type = items.itemizable_type AND legacy.itemizable_id = items.itemizable_id)
    SQL

    UPDATE_CHANGED_SQL = <<~SQL.squish.freeze
      UPDATE maintenance_order_items items
      SET tenant_id = legacy.tenant_id, maintenance_order_id = legacy.maintenance_order_id, description = legacy.description,
          notes = legacy.notes, total_cents = legacy.total_cents, updated_at = CURRENT_TIMESTAMP
      FROM (#{LEGACY_ITEMS_SQL}) legacy
      WHERE legacy.itemizable_type = items.itemizable_type AND legacy.itemizable_id = items.itemizable_id
        AND (items.tenant_id, items.maintenance_order_id, items.description, items.notes, items.total_cents)
            IS DISTINCT FROM (legacy.tenant_id, legacy.maintenance_order_id, legacy.description, legacy.notes, legacy.total_cents)
    SQL

    INSERT_MISSING_SQL = <<~SQL.squish.freeze
      INSERT INTO maintenance_order_items
        (tenant_id, maintenance_order_id, itemizable_type, itemizable_id, description, notes, total_cents, position, created_at, updated_at)
      SELECT legacy.tenant_id, legacy.maintenance_order_id, legacy.itemizable_type, legacy.itemizable_id, legacy.description,
             legacy.notes, legacy.total_cents,
             COALESCE((SELECT MAX(items.position) FROM maintenance_order_items items
                       WHERE items.maintenance_order_id = legacy.maintenance_order_id), 0)
               + ROW_NUMBER() OVER (PARTITION BY legacy.maintenance_order_id ORDER BY legacy.kind, legacy.itemizable_id),
             legacy.created_at, legacy.updated_at
      FROM (#{LEGACY_ITEMS_SQL}) legacy
      WHERE NOT EXISTS (SELECT 1 FROM maintenance_order_items items
                        WHERE items.itemizable_type = legacy.itemizable_type AND items.itemizable_id = legacy.itemizable_id)
    SQL

    class << self
      delegate :call, to: :new
    end

    def call
      MaintenanceOrderItem.transaction do
        { deleted: execute(DELETE_ORPHANS_SQL), updated: execute(UPDATE_CHANGED_SQL), created: execute(INSERT_MISSING_SQL) }
      end
    end

    private

    def execute(sql)
      MaintenanceOrderItem.connection.exec_update(sql)
    end
  end
end
