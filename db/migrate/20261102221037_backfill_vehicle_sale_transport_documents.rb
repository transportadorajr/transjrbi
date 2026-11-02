class BackfillVehicleSaleTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::ApplyVehicleSaleCommand.call(tenant) }
  end

  def down; end
end
