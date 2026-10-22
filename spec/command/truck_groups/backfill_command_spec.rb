require 'rails_helper'

RSpec.describe TruckGroups::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'without groups' do
    before { create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000) }

    it 'registers the active default groups without fuel' do
      expect { described_class.call(tenant) }.to change(TruckGroup, :count).by(3)

      expect(tenant.truck_groups.order(:id).map { |group| [group.name, group.axles, group.fuel_percentage, group.activated?] })
        .to eq([['Rodotrem', [9], 0, true], ['Quarto eixo', [7], 0, true], ['LS', [6], 0, true]])
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'when the tenant already has groups' do
    let!(:truck_group) { create(:truck_group, tenant:, name: 'Rodotrem 9 eixos') }

    it 'keeps the groups of the tenant' do
      expect { expect(described_class.call(tenant)).to eq([truck_group]) }.not_to change(TruckGroup, :count)
    end
  end
end
