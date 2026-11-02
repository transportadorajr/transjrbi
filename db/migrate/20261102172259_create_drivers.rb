class CreateDrivers < ActiveRecord::Migration[8.1]
  def change
    create_table :drivers do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.bigint :code, null: false
      t.string :display_name

      t.timestamps
    end

    add_index :drivers, %i[tenant_id code], unique: true
  end
end
