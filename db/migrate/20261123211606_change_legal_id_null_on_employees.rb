class ChangeLegalIdNullOnEmployees < ActiveRecord::Migration[8.1]
  def change
    change_column_null :employees, :legal_id, true
  end
end
