class CreateLifeInsurances < ActiveRecord::Migration[8.1]
  def change
    create_table :life_insurances do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true, index: false
      t.references :life_insurance_policy, null: false, foreign_key: true
      t.bigint :capital_cents
      t.date :included_on
      t.date :excluded_on

      t.timestamps
    end

    add_index :life_insurances, :employee_id, unique: true, where: 'excluded_on IS NULL',
                                              name: 'index_life_insurances_on_employee_id_not_excluded'
    add_index :life_insurances, %i[employee_id included_on]
  end
end
