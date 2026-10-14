class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_enum :location_precision_type, %w[address city]

    create_table :locations do |t|
      t.string :lookup_key, null: false
      t.string :street
      t.string :city, null: false
      t.string :state, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.enum :precision_type, enum_type: :location_precision_type, null: false
      t.string :formatted_address

      t.timestamps
    end

    add_index :locations, :lookup_key, unique: true
    add_index :locations, %i[latitude longitude]
  end
end
