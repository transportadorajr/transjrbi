class CreateMaintenanceOrderServices < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_order_services do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.string :description, null: false
      t.string :quote_number
      t.bigint :quoted_cents
      t.bigint :approved_cents
      t.string :approved_by_name
      t.string :invoice_number

      t.timestamps
    end
  end
end
