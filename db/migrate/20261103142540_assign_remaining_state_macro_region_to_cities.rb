class AssignRemainingStateMacroRegionToCities < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      Cities::RegisterOriginsCommand.call(tenant)
      MacroRegions::AssignCommand.call(tenant)
    end
  end

  def down; end
end
