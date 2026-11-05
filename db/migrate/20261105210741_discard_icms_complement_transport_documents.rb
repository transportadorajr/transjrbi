class DiscardIcmsComplementTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::DiscardIcmsComplementsCommand.call(tenant) }
  end

  def down; end
end
