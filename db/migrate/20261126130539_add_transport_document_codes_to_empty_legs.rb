class AddTransportDocumentCodesToEmptyLegs < ActiveRecord::Migration[8.1]
  def change
    change_table :empty_legs, bulk: true do |t|
      t.bigint :previous_transport_document_code
      t.bigint :next_transport_document_code
      t.change_null :previous_manifest_code, true
      t.change_null :next_manifest_code, true
    end

    add_index :empty_legs, %i[tenant_id next_transport_document_code], unique: true
    add_index :empty_legs, %i[tenant_id previous_transport_document_code]
  end
end
