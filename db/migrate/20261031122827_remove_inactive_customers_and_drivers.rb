class RemoveInactiveCustomersAndDrivers < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      Atua::PurgeInactiveCustomersCommand.call(tenant)
      Atua::PurgeInactiveDriversCommand.call(tenant)
    end
  end

  def down; end
end
