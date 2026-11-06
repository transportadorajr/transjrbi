class DiscardTarpLiningExpenses < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::DiscardTarpLiningExpensesCommand.call(tenant) }
  end

  def down; end
end
