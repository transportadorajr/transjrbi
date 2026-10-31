class RemoveUnusedCustomerGroups < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| CustomerGroups::PurgeUnusedCommand.call(tenant) }
  end

  def down; end
end
