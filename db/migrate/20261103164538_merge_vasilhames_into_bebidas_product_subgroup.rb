class MergeVasilhamesIntoBebidasProductSubgroup < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| ProductGroups::MergeSubgroupCommand.call(tenant, 'VASILHAMES', 'BEBIDAS') }
  end

  def down; end
end
