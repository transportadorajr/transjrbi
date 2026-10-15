class AddCustomerGroupToAtuaCustomers < ActiveRecord::Migration[8.1]
  def change
    add_reference :atua_customers, :customer_group, foreign_key: true
  end
end
