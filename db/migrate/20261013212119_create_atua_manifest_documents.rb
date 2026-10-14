class CreateAtuaManifestDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_manifest_documents do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :manifest_code, null: false
      t.string :branch_name
      t.string :transport_document_number, null: false
      t.integer :transport_document_series
      t.string :goods_invoice_numbers, array: true, null: false, default: []
      t.bigint :goods_value_cents
      t.decimal :weight_kg, precision: 14, scale: 2
      t.decimal :weight_tons, precision: 14, scale: 3
      t.bigint :freight_cents
      t.string :freight_payment
      t.string :sender_name
      t.string :recipient_name
      t.string :origin_agency_name
      t.string :origin_state
      t.string :origin_city
      t.string :destination_state
      t.string :destination_city
      t.decimal :calculated_distance_km, precision: 14, scale: 2
      t.decimal :document_distance_km, precision: 14, scale: 2
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_manifest_documents, %i[tenant_id manifest_code transport_document_number transport_document_series],
              unique: true, name: 'index_atua_manifest_documents_on_source_key'
    add_index :atua_manifest_documents, %i[tenant_id transport_document_number transport_document_series branch_name],
              name: 'index_atua_manifest_documents_on_transport_document'
  end
end
