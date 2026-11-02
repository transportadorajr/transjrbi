class DiscardExcludedPlateRecords < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      EmptyLegs::ScheduleCalculationCommand.call(tenant.id) if Atua::DiscardExcludedPlatesCommand.call(tenant).positive?
    end
  end

  def down; end
end
