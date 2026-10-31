class CreateTruckGroupFuelRates < ActiveRecord::Migration[8.1]
  def change
    create_table :truck_group_fuel_rates do |t|
      t.references :truck_group, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :valid_month, null: false
      t.decimal :percentage, precision: 7, scale: 4, null: false

      t.timestamps
    end

    add_index :truck_group_fuel_rates, %i[truck_group_id valid_month], unique: true
  end
end
