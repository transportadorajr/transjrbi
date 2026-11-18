class CreateExportShortcuts < ActiveRecord::Migration[8.1]
  def change
    create_table :export_shortcuts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer_group, foreign_key: true
      t.string :name, null: false
      t.bigint :export_plant_ids, array: true, default: [], null: false
      t.string :countries, array: true, default: [], null: false
      t.integer :position, null: false, default: 0
      t.datetime :activated_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :export_shortcuts, %i[tenant_id name], unique: true
  end
end
