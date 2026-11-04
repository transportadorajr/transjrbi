class RecalculateInsuranceOfExportCargo < ActiveRecord::Migration[8.1]
  def up
    FreightExpense.reset_column_information

    Tenant.find_each do |tenant|
      FreightExpenses::CalculateInsuranceCommand.call(tenant)
    end
  end

  def down; end
end
