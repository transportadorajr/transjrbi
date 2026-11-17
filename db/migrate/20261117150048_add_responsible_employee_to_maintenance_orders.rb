class AddResponsibleEmployeeToMaintenanceOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :maintenance_orders, :responsible_employee, foreign_key: { to_table: :workshop_employees }
  end
end
