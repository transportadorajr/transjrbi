class RecreateAtuaManifestDocumentsSourceKeyWithNullsNotDistinct < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_atua_manifest_documents_on_source_key'.freeze
  COLUMNS = %i[tenant_id manifest_code transport_document_number transport_document_series].freeze

  def up
    execute <<~SQL.squish
      DELETE FROM atua_manifest_documents
      WHERE id NOT IN (
        SELECT MAX(id) FROM atua_manifest_documents
        GROUP BY tenant_id, manifest_code, transport_document_number, transport_document_series
      )
    SQL

    remove_index :atua_manifest_documents, name: INDEX_NAME
    add_index :atua_manifest_documents, COLUMNS, name: INDEX_NAME, unique: true, nulls_not_distinct: true
  end

  def down
    remove_index :atua_manifest_documents, name: INDEX_NAME
    add_index :atua_manifest_documents, COLUMNS, name: INDEX_NAME, unique: true
  end
end
