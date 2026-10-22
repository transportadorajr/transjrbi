class BackfillTruckGroups < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| TruckGroups::BackfillCommand.call(tenant) }
  end

  def down; end
end
