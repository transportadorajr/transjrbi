class CreateOwnFleets < ActiveRecord::Migration[8.1]
  def change
    create_table :own_fleets do |t|
      t.references :tenant, null: false, foreign_key: true, index: { unique: true }
      t.string :plates, array: true, null: false, default: []

      t.timestamps
    end
  end
end
