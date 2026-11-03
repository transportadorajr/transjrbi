class AddObservationToAtuaExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :atua_expenses, :observation, :text
  end
end
