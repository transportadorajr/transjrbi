class CreateInsuranceRates < ActiveRecord::Migration[8.1]
  def change
    create_table :insurance_rates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :valid_from, null: false
      t.decimal :insurance_percentage, precision: 7, scale: 4, null: false
      t.decimal :iof_percentage, precision: 7, scale: 4, null: false

      t.timestamps
    end

    add_index :insurance_rates, %i[tenant_id valid_from], unique: true
  end
end
