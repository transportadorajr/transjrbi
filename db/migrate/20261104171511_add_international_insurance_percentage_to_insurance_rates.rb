class AddInternationalInsurancePercentageToInsuranceRates < ActiveRecord::Migration[8.1]
  def up
    add_column :insurance_rates, :international_insurance_percentage, :decimal, precision: 7, scale: 4
    execute 'UPDATE insurance_rates SET international_insurance_percentage = 0.065'
    change_column_null :insurance_rates, :international_insurance_percentage, false
  end

  def down
    remove_column :insurance_rates, :international_insurance_percentage
  end
end
