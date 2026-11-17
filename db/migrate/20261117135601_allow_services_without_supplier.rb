class AllowServicesWithoutSupplier < ActiveRecord::Migration[8.1]
  def change
    change_column_null :maintenance_order_services, :supplier_id, true
  end
end
