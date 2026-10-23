class CreateRemainingAxlesTruckGroups < ActiveRecord::Migration[8.1]
  FUEL_PERCENTAGE = 33

  def up
    Tenant.find_each do |tenant|
      TruckGroups::CreateRemainingAxlesCommand.call(tenant, fuel_percentage: FUEL_PERCENTAGE)
      FreightExpenses::CalculateFuelCommand.call(tenant)
    end
  end

  def down; end
end
