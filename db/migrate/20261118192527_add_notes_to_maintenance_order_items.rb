class AddNotesToMaintenanceOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :maintenance_order_parts, :notes, :text
    add_column :maintenance_order_services, :notes, :text
  end
end
