class CreateExcludedIssuers < ActiveRecord::Migration[8.1]
  def change
    create_table :excluded_issuers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.integer :code, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :excluded_issuers, %i[tenant_id code], unique: true
  end
end
