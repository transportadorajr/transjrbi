class AddInsuranceToFreightExpenses < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :freight_expense_kind_type, 'insurance'

    add_reference :freight_expenses, :insurance_rate, foreign_key: true
    add_column :freight_expenses, :iof_percentage, :decimal, precision: 7, scale: 4
    add_column :freight_expenses, :iof_cents, :bigint, null: false, default: 0
  end

  def down
    execute "DELETE FROM freight_expenses WHERE kind_type = 'insurance'"

    remove_column :freight_expenses, :iof_cents
    remove_column :freight_expenses, :iof_percentage
    remove_reference :freight_expenses, :insurance_rate, foreign_key: true
  end
end
