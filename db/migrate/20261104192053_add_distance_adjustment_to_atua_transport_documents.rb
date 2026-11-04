class AddDistanceAdjustmentToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    change_table :atua_transport_documents, bulk: true do |t|
      t.decimal :original_distance_km, precision: 14, scale: 2
      t.datetime :distance_adjusted_at
    end
  end
end
