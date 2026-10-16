class AddTonnageToFreightExpenses < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :freight_expense_kind_type, 'tonnage'

    add_reference :freight_expenses, :tonnage_rate, foreign_key: true
    add_column :freight_expenses, :weight_tons, :decimal, precision: 14, scale: 3
    add_column :freight_expenses, :rate_cents, :bigint
    change_column_null :freight_expenses, :base_cents, true
    change_column_null :freight_expenses, :percentage, true
  end

  def down
    execute "DELETE FROM freight_expenses WHERE kind_type = 'tonnage'"

    change_column_null :freight_expenses, :percentage, false
    change_column_null :freight_expenses, :base_cents, false
    remove_column :freight_expenses, :rate_cents
    remove_column :freight_expenses, :weight_tons
    remove_reference :freight_expenses, :tonnage_rate, foreign_key: true
  end
end
