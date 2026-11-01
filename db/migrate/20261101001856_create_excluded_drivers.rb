class CreateExcludedDrivers < ActiveRecord::Migration[8.1]
  def change
    create_table :excluded_drivers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.bigint :code, null: false
      t.string :name

      t.timestamps
    end

    add_index :excluded_drivers, %i[tenant_id code], unique: true
  end
end
