class BackfillSiderTruckGroup < ActiveRecord::Migration[8.1]
  def up
    TruckGroup.reset_column_information

    Tenant.find_each do |tenant|
      TruckGroups::CreateSiderCommand.call(tenant)
      FreightExpenses::CalculateFuelCommand.call(tenant)
    end
  end

  def down; end
end
