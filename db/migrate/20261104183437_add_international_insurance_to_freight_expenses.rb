class AddInternationalInsuranceToFreightExpenses < ActiveRecord::Migration[8.1]
  def change
    change_table :freight_expenses, bulk: true do |t|
      t.decimal :international_percentage, precision: 7, scale: 4
      t.bigint :international_insurance_cents, default: 0, null: false
    end
  end
end
