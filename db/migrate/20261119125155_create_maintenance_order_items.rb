class CreateMaintenanceOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_order_items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true, index: false
      t.string :itemizable_type, null: false
      t.bigint :itemizable_id, null: false
      t.string :description, null: false
      t.text :notes
      t.bigint :total_cents, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :maintenance_order_items, %i[itemizable_type itemizable_id], unique: true, name: 'index_maintenance_order_items_on_itemizable'
    add_index :maintenance_order_items, %i[maintenance_order_id position], name: 'index_maintenance_order_items_on_order_and_position'
  end
end
