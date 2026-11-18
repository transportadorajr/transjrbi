class CreateExportPlants < ActiveRecord::Migration[8.1]
  def change
    create_table :export_plants do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer_group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :cities, array: true, default: [], null: false
      t.datetime :activated_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :export_plants, %i[tenant_id customer_group_id name], unique: true
  end
end
