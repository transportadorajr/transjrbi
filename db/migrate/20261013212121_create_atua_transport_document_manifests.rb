class CreateAtuaTransportDocumentManifests < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_transport_document_manifests do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :transport_document_code, null: false
      t.string :manifest_number, null: false
      t.string :branch_name
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_transport_document_manifests, %i[tenant_id transport_document_code manifest_number],
              unique: true, name: 'index_atua_transport_document_manifests_on_source_key'
    add_index :atua_transport_document_manifests, %i[tenant_id manifest_number branch_name],
              name: 'index_atua_transport_document_manifests_on_manifest'
  end
end
