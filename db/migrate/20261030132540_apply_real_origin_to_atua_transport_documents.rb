class ApplyRealOriginToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::ApplyRealOriginCommand.call(tenant) }
  end

  def down; end
end
