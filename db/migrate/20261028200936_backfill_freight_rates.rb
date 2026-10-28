class BackfillFreightRates < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      CommissionRules::BackfillCommand.call(tenant)
      TonnageRates::BackfillCommand.call(tenant)
      InsuranceRates::BackfillCommand.call(tenant)
      FreightExpenses::CalculateJob.perform_now(tenant.id)
    end
  end

  def down; end
end
