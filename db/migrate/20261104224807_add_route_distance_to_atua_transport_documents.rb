class AddRouteDistanceToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :atua_transport_documents, :route_distance, foreign_key: { on_delete: :nullify }
  end
end
