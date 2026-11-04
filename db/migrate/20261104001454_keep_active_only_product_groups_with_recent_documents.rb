class KeepActiveOnlyProductGroupsWithRecentDocuments < ActiveRecord::Migration[8.1]
  def up
    period = (3.months.ago..)

    Tenant.find_each { |tenant| ProductGroups::ActivateByDocumentsCommand.call(tenant, period) }
  end

  def down; end
end
