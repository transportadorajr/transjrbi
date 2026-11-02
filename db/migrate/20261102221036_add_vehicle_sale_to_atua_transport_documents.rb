class AddVehicleSaleToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :atua_transport_documents, :vehicle_sale, :boolean, null: false, default: false
    add_index :atua_transport_documents, %i[tenant_id vehicle_sale]
  end
end
