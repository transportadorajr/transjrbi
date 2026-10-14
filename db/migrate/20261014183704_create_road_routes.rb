class CreateRoadRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :road_routes do |t|
      t.references :origin, null: false, foreign_key: { to_table: :locations }, index: false
      t.references :destination, null: false, foreign_key: { to_table: :locations }
      t.decimal :distance_km, precision: 14, scale: 2, null: false
      t.integer :travel_time_seconds

      t.timestamps
    end

    add_index :road_routes, %i[origin_id destination_id], unique: true
  end
end
