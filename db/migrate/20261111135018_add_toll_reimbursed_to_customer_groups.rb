class AddTollReimbursedToCustomerGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_groups, :toll_reimbursed, :boolean, null: false, default: false
  end
end
