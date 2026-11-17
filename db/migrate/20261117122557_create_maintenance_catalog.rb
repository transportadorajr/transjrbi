class CreateMaintenanceCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_parts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code
      t.string :description, null: false
      t.string :unit
      t.string :brand
      t.bigint :unit_price_cents, default: 0, null: false
      t.decimal :quantity, precision: 12, scale: 3, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :maintenance_parts, %i[tenant_id code], unique: true, where: 'code IS NOT NULL'
    add_index :maintenance_parts, %i[tenant_id description], unique: true

    create_table :maintenance_services do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code
      t.string :description, null: false
      t.bigint :price_cents, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :maintenance_services, %i[tenant_id code], unique: true, where: 'code IS NOT NULL'
    add_index :maintenance_services, %i[tenant_id description], unique: true

    create_enum :maintenance_part_movement_type, %w[entry exit adjustment]

    create_table :maintenance_part_movements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_part, null: false, foreign_key: true
      t.enum :movement_type, enum_type: :maintenance_part_movement_type, null: false
      t.date :moved_on, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.decimal :balance, precision: 12, scale: 3, null: false
      t.bigint :unit_cost_cents
      t.references :supplier, foreign_key: true
      t.string :invoice_number
      t.references :maintenance_order, foreign_key: true
      t.references :maintenance_order_part, foreign_key: true, index: { unique: true }
      t.references :created_by, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end

    add_index :maintenance_part_movements, %i[maintenance_part_id moved_on]

    add_reference :maintenance_order_parts, :maintenance_part, foreign_key: true
    add_reference :maintenance_order_services, :maintenance_service, foreign_key: true
  end
end
