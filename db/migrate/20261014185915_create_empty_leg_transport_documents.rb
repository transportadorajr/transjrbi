class CreateEmptyLegTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :empty_leg_transport_documents do |t|
      t.references :empty_leg, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tenant, null: false, foreign_key: true, index: false
      t.bigint :transport_document_code, null: false

      t.timestamps
    end

    add_index :empty_leg_transport_documents, %i[empty_leg_id transport_document_code], unique: true
    add_index :empty_leg_transport_documents, %i[tenant_id transport_document_code]
  end
end
