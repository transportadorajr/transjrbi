class CreateMaintenanceOrderParts < ActiveRecord::Migration[8.1]
  def change
    create_enum :maintenance_order_part_source_type, %w[stock purchase]

    create_table :maintenance_order_parts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true
      t.string :code
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.string :unit
      t.enum :source_type, enum_type: :maintenance_order_part_source_type, null: false, default: 'stock'
      t.string :document_number
      t.bigint :unit_price_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0

      t.timestamps
    end
  end
end
