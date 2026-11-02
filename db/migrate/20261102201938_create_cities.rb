class CreateCities < ActiveRecord::Migration[8.1]
  def change
    create_table :cities do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :macro_region, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :state, null: false

      t.timestamps
    end

    add_index :cities, %i[tenant_id state name], unique: true
  end
end
