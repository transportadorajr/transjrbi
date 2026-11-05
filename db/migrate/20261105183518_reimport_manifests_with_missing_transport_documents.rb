class ReimportManifestsWithMissingTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Atua.enabled_tenants.find_each do |tenant|
      Atua::DiscardManifestsBeforeCutoffCommand.call(tenant)
      Atua::ReimportManifestsWithMissingDocumentsCommand.call(tenant)
    end
  end

  def down; end
end
