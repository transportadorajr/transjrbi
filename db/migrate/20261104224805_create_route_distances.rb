class CreateRouteDistances < ActiveRecord::Migration[8.1]
  def change
    create_table :route_distances do |t|
      t.references :tenant, null: false, foreign_key: true
      t.bigint :customer_code, null: false
      t.string :origin_city, null: false
      t.string :origin_state, null: false
      t.string :destination_city, null: false
      t.string :destination_state, null: false
      t.decimal :distance_km, precision: 14, scale: 2, null: false

      t.timestamps
    end

    add_index :route_distances, %i[tenant_id customer_code origin_state origin_city destination_state destination_city],
              unique: true, name: 'index_route_distances_on_customer_and_route'
  end
end
