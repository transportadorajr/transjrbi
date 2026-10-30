class BackfillCustomerGroupNames < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| CustomerGroups::BackfillCommand.call(tenant) }
  end

  def down; end
end
