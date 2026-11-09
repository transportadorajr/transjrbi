class AddDistanceEditedAtToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :atua_transport_documents, :distance_edited_at, :datetime
  end
end
