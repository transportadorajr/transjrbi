class CreateMaintenanceOrderLabors < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_order_labors do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true
      t.references :workshop_employee, null: false, foreign_key: true
      t.date :worked_on, null: false
      t.time :start_time
      t.time :end_time
      t.decimal :hours, precision: 6, scale: 2
      t.text :activity

      t.timestamps
    end
  end
end
