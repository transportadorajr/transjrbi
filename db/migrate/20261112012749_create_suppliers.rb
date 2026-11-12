class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :document
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :suppliers, %i[tenant_id name], unique: true
  end
end
