class AddAdvanceIcmsToFreightExpenseKindType < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :freight_expense_kind_type, 'advance_icms'
  end

  def down
    execute "DELETE FROM freight_expenses WHERE kind_type = 'advance_icms'"
  end
end
