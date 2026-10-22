class CreateTruckGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :truck_groups do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :axles, array: true, null: false, default: []
      t.decimal :fuel_percentage, precision: 7, scale: 4, null: false, default: 0
      t.datetime :activated_at

      t.timestamps
    end

    add_index :truck_groups, %i[tenant_id name], unique: true

    add_reference :freight_expenses, :truck_group, foreign_key: true
  end
end
