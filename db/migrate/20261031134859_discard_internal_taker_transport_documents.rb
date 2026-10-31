class DiscardInternalTakerTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::DiscardInternalTakerDocumentsCommand.call(tenant) }
  end

  def down; end
end
