class BackfillOwnFleet < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| OwnFleets::BackfillCommand.call(tenant) }
  end

  def down; end
end
