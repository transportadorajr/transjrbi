class CreateMaintenanceOrderMechanics < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_order_mechanics do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true
      t.references :workshop_employee, null: false, foreign_key: true

      t.timestamps
    end

    add_index :maintenance_order_mechanics, %i[maintenance_order_id workshop_employee_id], unique: true,
                                                                                           name: 'index_maintenance_order_mechanics_uniqueness'

    up_only do
      execute <<~SQL.squish
        INSERT INTO maintenance_order_mechanics (tenant_id, maintenance_order_id, workshop_employee_id, created_at, updated_at)
        SELECT tenant_id, id, responsible_employee_id, NOW(), NOW()
        FROM maintenance_orders
        WHERE responsible_employee_id IS NOT NULL
      SQL
    end
  end
end
