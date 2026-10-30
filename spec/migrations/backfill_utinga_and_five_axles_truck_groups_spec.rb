require 'rails_helper'
require Rails.root.join('db/migrate/20261030194611_backfill_utinga_and_five_axles_truck_groups')

RSpec.describe BackfillUtingaAndFiveAxlesTruckGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with transport documents already calculated by the remaining axles group' do
    let!(:tenant) { create(:tenant) }
    let!(:others) { create(:truck_group, :others, tenant:) }
    let!(:ls) { create(:truck_group, :ls, tenant:, fuel_percentage: BigDecimal('33')) }
    let!(:listed) { create(:atua_transport_document, tenant:, plate: 'BAV5A04', axles: 6, freight_cents: 1_000_000) }
    let!(:evo) { create(:atua_transport_document, tenant:, plate: 'EVO8C24', axles: 5, freight_cents: 1_000_000) }
    let!(:five_axles) { create(:atua_transport_document, tenant:, plate: 'BBU2B93', axles: 5, freight_cents: 1_000_000) }
    let!(:unrelated) { create(:atua_transport_document, tenant:, plate: 'RVR2C34', axles: 6, freight_cents: 1_000_000) }

    before { FreightExpenses::CalculateFuelCommand.call(tenant) }

    it 'creates the groups and recalculates the fuel of their transport documents' do
      expect { migration.up }.to change(TruckGroup, :count).by(2).and(not_change(FreightExpense, :count))

      utinga = TruckGroup.find_by!(name: 'Utinga')
      five = TruckGroup.find_by!(name: '5 eixos')
      expect(FreightExpense.fuel.find_by!(transport_document: listed)).to have_attributes(truck_group: utinga, percentage: 28, amount_cents: 280_000)
      expect(FreightExpense.fuel.find_by!(transport_document: evo)).to have_attributes(truck_group: utinga, percentage: 28, amount_cents: 280_000)
      expect(FreightExpense.fuel.find_by!(transport_document: five_axles)).to have_attributes(truck_group: five, percentage: 35, amount_cents: 350_000)
      expect(FreightExpense.fuel.find_by!(transport_document: unrelated)).to have_attributes(truck_group: ls, percentage: 33, amount_cents: 330_000)
    end

    it 'can run again without changing the groups or the fuel' do
      migration.up

      expect { migration.up }.not_to(change { [TruckGroup.count, FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at)] })
    end
  end
end
