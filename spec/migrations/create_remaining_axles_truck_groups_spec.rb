require 'rails_helper'
require Rails.root.join('db/migrate/20261022190834_create_remaining_axles_truck_groups')

RSpec.describe CreateRemainingAxlesTruckGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }
    let!(:truck) { create(:atua_transport_document, tenant:, axles: 4, freight_cents: 1_000_000) }

    before { create(:truck_group, tenant:, axles: [9], fuel_percentage: 29) }

    it 'registers the group of the remaining axles with 33% of fuel and calculates the fuel' do
      expect { migration.up }.to change(TruckGroup, :count).by(2).and change(FreightExpense, :count).by(1)

      expect(TruckGroup.where(remaining_axles: true).pluck(:tenant_id, :name, :fuel_percentage))
        .to contain_exactly([tenant.id, 'Outros', 33], [other_tenant.id, 'Outros', 33])
      expect(FreightExpense.fuel.sole).to have_attributes(transport_document: truck, amount_cents: 330_000)
    end

    it 'can run again without duplicating the groups' do
      migration.up

      expect { migration.up }.not_to change { [TruckGroup.count, FreightExpense.count] }
    end
  end
end
