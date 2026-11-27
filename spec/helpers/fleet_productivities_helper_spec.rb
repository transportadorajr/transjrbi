require 'rails_helper'

RSpec.describe FleetProductivitiesHelper do
  let!(:tenant) { create(:tenant) }

  def dashboard
    Dashboard::FleetProductivity.new(tenant.empty_legs, macro_regions: tenant.macro_regions)
  end

  describe '#fleet_productivity_km' do
    it 'rounds the distance and shows a dash without one' do
      expect(helper.fleet_productivity_km(BigDecimal('1234.6'))).to eq('1.235 km')
      expect(helper.fleet_productivity_km(nil)).to eq('-')
    end
  end

  describe '#fleet_productivity_routes_chart_card' do
    context 'without a measured empty leg' do
      before { create(:empty_leg, tenant:, status_type: 'unrouted', distance_km: nil) }

      it 'shows no chart' do
        expect(helper.fleet_productivity_routes_chart_card(dashboard)).to be_nil
      end
    end
  end
end
