class CreateLifeInsurancePolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :life_insurance_policies do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.enum :company_type, enum_type: :employee_company_type, null: false
      t.bigint :capital_cents, null: false
      t.decimal :premium_rate_per_mille, precision: 8, scale: 4, null: false
      t.decimal :spouse_percentage, precision: 5, scale: 2, null: false, default: 50
      t.decimal :children_percentage, precision: 5, scale: 2, null: false, default: 10
      t.bigint :funeral_assistance_cents, null: false, default: 0

      t.timestamps
    end

    add_index :life_insurance_policies, %i[tenant_id company_type], unique: true
  end
end
