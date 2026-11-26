class AddCustomerGroupEditedAtToAtuaCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :atua_customers, :customer_group_edited_at, :datetime
  end
end
