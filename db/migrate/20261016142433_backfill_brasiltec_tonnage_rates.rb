class BackfillBrasiltecTonnageRates < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| TonnageRates::BackfillCommand.call(tenant) }
  end

  def down; end
end
