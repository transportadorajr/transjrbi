class CreateTonnageRates < ActiveRecord::Migration[8.1]
  def change
    create_table :tonnage_rates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer_group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :nickname
      t.string :origin_city, null: false
      t.string :origin_state, null: false
      t.date :valid_month, null: false
      t.bigint :rate_cents, null: false
      t.datetime :activated_at

      t.timestamps
    end

    add_index :tonnage_rates, %i[tenant_id valid_month]
  end
end
