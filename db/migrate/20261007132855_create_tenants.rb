class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :legal_id, null: false
      t.string :trade_name, null: false

      t.timestamps
    end

    add_index :tenants, :legal_id, unique: true
  end
end
