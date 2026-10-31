class BackfillTruckGroupFuelRates < ActiveRecord::Migration[8.1]
  def up
    TruckGroup.reset_column_information

    TruckGroup.where.missing(:fuel_rates).find_each do |truck_group|
      truck_group.fuel_rates.create!(valid_month: Date.current.beginning_of_month, percentage: truck_group.fuel_percentage)
    end
  end

  def down; end
end
