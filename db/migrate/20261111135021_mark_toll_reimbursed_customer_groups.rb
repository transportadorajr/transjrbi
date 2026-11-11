class MarkTollReimbursedCustomerGroups < ActiveRecord::Migration[8.1]
  GROUPS = %w[INDEMIL SOORO].freeze

  def up
    CustomerGroup.reset_column_information
    CustomerGroup.where(name: GROUPS).update_all(toll_reimbursed: true, updated_at: Time.current)
  end

  def down; end
end
