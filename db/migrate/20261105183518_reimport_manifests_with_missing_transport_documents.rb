class ReimportManifestsWithMissingTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Atua.enabled_tenants.find_each do |tenant|
      Atua::ReimportManifestsWithMissingDocumentsCommand.call(tenant)
      EmptyLegs::ScheduleCalculationCommand.call(tenant.id)
    end
  end

  def down; end
end
