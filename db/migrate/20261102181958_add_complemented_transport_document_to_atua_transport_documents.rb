class AddComplementedTransportDocumentToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :atua_transport_documents, :complemented_transport_document,
                  foreign_key: { to_table: :atua_transport_documents, on_delete: :nullify }
  end
end
