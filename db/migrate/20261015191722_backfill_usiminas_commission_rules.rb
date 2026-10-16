class BackfillUsiminasCommissionRules < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| CommissionRules::BackfillCommand.call(tenant) }
  end

  def down; end
end
