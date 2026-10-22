class BackfillMacroRegions < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| MacroRegions::BackfillCommand.call(tenant) }
  end

  def down; end
end
