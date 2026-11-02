class BackfillProductGroups < ActiveRecord::Migration[8.1]
  def up
    ProductGroup.reset_column_information
    Atua::TransportDocument.reset_column_information

    Tenant.find_each { |tenant| ProductGroups::BackfillCommand.call(tenant) }
  end

  def down; end
end
