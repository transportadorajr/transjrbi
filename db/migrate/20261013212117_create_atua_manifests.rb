class CreateAtuaManifests < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_manifests do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :code, null: false
      t.integer :model
      t.string :number, null: false
      t.integer :series
      t.string :branch_name
      t.string :company_state
      t.string :company_city
      t.date :issued_on
      t.date :departure_on
      t.datetime :trip_started_at
      t.datetime :closed_at
      t.text :notes
      t.string :plate
      t.string :access_key
      t.bigint :goods_value_cents
      t.string :status
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_manifests, %i[tenant_id code], unique: true
    add_index :atua_manifests, %i[tenant_id number branch_name]
    add_index :atua_manifests, %i[tenant_id issued_on]
    add_index :atua_manifests, %i[tenant_id departure_on]
    add_index :atua_manifests, %i[tenant_id plate]
    add_index :atua_manifests, %i[tenant_id status]
  end
end
