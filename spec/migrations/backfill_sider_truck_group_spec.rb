require 'rails_helper'
require Rails.root.join('db/migrate/20261102170323_backfill_sider_truck_group')

RSpec.describe BackfillSiderTruckGroup do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with transport documents of 6 axles already calculated by the LS group' do
    let!(:tenant) { create(:tenant) }
    let!(:ls) { create(:truck_group, :ls, tenant:, name: 'LS', fuel_percentage: BigDecimal('33')) }
    let!(:sider_document) { create(:atua_transport_document, tenant:, plate: 'RHJ5A51', axles: 6, freight_cents: 1_000_000) }
    let!(:six_axles_document) { create(:atua_transport_document, tenant:, plate: 'RVR2C34', axles: 6, freight_cents: 1_000_000) }

    before { FreightExpenses::CalculateFuelCommand.call(tenant) }

    it 'renames the LS group and moves the Sider plates to their own group keeping the fuel' do
      expect { migration.up }.to change(TruckGroup, :count).by(1).and(not_change(FreightExpense, :count))

      sider = TruckGroup.find_by!(name: 'Sider')
      expect(ls.reload.name).to eq('6 eixos')
      expect(FreightExpense.fuel.find_by!(transport_document: sider_document)).to have_attributes(truck_group: sider, percentage: 33, amount_cents: 330_000)
      expect(FreightExpense.fuel.find_by!(transport_document: six_axles_document)).to have_attributes(truck_group: ls, percentage: 33, amount_cents: 330_000)
    end

    it 'can run again without changing the groups or the fuel' do
      migration.up

      expect { migration.up }.not_to(change { [TruckGroup.pluck(:id, :name), FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at)] })
    end
  end
end
