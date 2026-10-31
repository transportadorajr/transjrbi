require 'rails_helper'
require Rails.root.join('db/migrate/20261031203731_backfill_truck_group_fuel_rates')

RSpec.describe BackfillTruckGroupFuelRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a group without rates' do
    let!(:truck_group) { create(:truck_group, fuel_percentage: BigDecimal('32.5')) }

    before { truck_group.fuel_rates.delete_all }

    it 'records the current percentage and can run again' do
      expect { migration.up }.to change(TruckGroupFuelRate, :count).by(1)
      expect { migration.up }.not_to change(TruckGroupFuelRate, :count)

      expect(truck_group.fuel_rates.reload.sole).to have_attributes(valid_month: Date.current.beginning_of_month, percentage: BigDecimal('32.5'))
    end
  end
end
