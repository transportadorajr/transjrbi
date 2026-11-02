class MoveArcelorExportCesToInternationalPlate < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      Atua::ApplyInternationalVehicleCommand.call(tenant)
      FreightExpenses::CalculateJob.perform_now(tenant.id)
    end
  end

  def down; end
end
