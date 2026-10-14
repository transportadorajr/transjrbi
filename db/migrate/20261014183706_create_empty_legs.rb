class CreateEmptyLegs < ActiveRecord::Migration[8.1]
  def change
    create_enum :empty_leg_status_type, %w[calculated unlocated unrouted]

    create_table :empty_legs do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.string :plate, null: false
      t.bigint :previous_manifest_code, null: false
      t.bigint :next_manifest_code, null: false
      t.references :origin, foreign_key: { to_table: :locations }
      t.references :destination, foreign_key: { to_table: :locations }
      t.references :road_route, foreign_key: true
      t.decimal :distance_km, precision: 14, scale: 2
      t.enum :precision_type, enum_type: :location_precision_type
      t.enum :status_type, enum_type: :empty_leg_status_type, null: false
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :empty_legs, %i[tenant_id next_manifest_code], unique: true
    add_index :empty_legs, %i[tenant_id previous_manifest_code]
    add_index :empty_legs, %i[tenant_id plate]
  end
end
