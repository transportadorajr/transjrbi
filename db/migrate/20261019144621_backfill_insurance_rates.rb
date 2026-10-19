class BackfillInsuranceRates < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| InsuranceRates::BackfillCommand.call(tenant) }
  end

  def down; end
end
