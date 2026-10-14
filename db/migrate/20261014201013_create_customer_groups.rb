class CreateCustomerGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_groups do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :terms, array: true, null: false, default: []
      t.datetime :activated_at

      t.timestamps
    end

    add_index :customer_groups, %i[tenant_id name], unique: true
  end
end
