class AddCostObjectToAtuaExpenses < ActiveRecord::Migration[8.1]
  def change
    add_reference :atua_expenses, :cost_object, polymorphic: true, index: true
  end
end
