class AddTarpLiningToFreightExpenseKindType < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :freight_expense_kind_type, 'tarp_lining'
  end

  def down
    execute "DELETE FROM freight_expenses WHERE kind_type = 'tarp_lining'"
  end
end
