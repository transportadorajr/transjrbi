class AddEstimatedCompletionAtToMaintenanceOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :maintenance_orders, :estimated_completion_at, :datetime
  end
end
