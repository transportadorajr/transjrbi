class AddAtuaPostingToMaintenanceOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :maintenance_orders, :atua_order_number, :string
    add_column :maintenance_orders, :posted_on, :date
    add_reference :maintenance_orders, :posted_by, foreign_key: { to_table: :users }
    add_column :maintenance_orders, :posting_verified, :boolean, default: false, null: false

    add_index :maintenance_orders, %i[tenant_id atua_order_number], unique: true, where: 'atua_order_number IS NOT NULL'
  end
end
