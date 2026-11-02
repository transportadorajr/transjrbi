class CreateProductGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :product_groups do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :product_groups }
      t.string :name, null: false
      t.string :product_names, array: true, null: false, default: []
      t.datetime :activated_at

      t.timestamps
    end

    add_index :product_groups, %i[tenant_id parent_id name], unique: true, nulls_not_distinct: true
  end
end
