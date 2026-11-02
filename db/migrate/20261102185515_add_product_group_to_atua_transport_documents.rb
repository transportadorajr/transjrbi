class AddProductGroupToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :atua_transport_documents, :product_group, foreign_key: true
  end
end
