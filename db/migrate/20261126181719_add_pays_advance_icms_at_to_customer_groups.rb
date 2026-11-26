class AddPaysAdvanceIcmsAtToCustomerGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_groups, :pays_advance_icms_at, :datetime
  end
end
