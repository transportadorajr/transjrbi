class ReimportManifestsWithInactiveTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Atua.enabled_tenants.find_each { |tenant| Atua::ReimportManifestsWithInactiveDocumentsCommand.call(tenant) }
  end

  def down; end
end
