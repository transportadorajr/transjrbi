class CreateMacroRegions < ActiveRecord::Migration[8.1]
  def change
    create_table :macro_regions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :state, null: false
      t.string :cities, array: true, null: false, default: []
      t.boolean :remaining_state, null: false, default: false

      t.timestamps
    end

    add_index :macro_regions, %i[tenant_id name], unique: true
    add_index :macro_regions, %i[tenant_id state], unique: true, where: 'remaining_state', name: 'index_macro_regions_on_remaining_state'

    add_reference :atua_transport_documents, :origin_macro_region, foreign_key: { to_table: :macro_regions, on_delete: :nullify }
  end
end
