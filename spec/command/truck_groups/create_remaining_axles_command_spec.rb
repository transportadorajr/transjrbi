require 'rails_helper'

RSpec.describe TruckGroups::CreateRemainingAxlesCommand do
  let(:tenant) { create(:tenant) }

  context 'without a group of the remaining axles' do
    before { create(:truck_group, tenant:) }

    it 'registers the active group of the remaining axles with the fuel percentage' do
      expect { described_class.call(tenant, fuel_percentage: 33) }.to change(TruckGroup, :count).by(1)

      expect(TruckGroup.last).to have_attributes(tenant:, name: 'Outros', axles: [], remaining_axles: true,
                                                 fuel_percentage: BigDecimal('33'), activated?: true)
    end

    it 'registers the group without fuel by default' do
      expect(described_class.call(tenant).fuel_percentage).to eq(0)
    end
  end

  context 'when the tenant already has a group of the remaining axles' do
    let!(:truck_group) { create(:truck_group, :others, tenant:, name: 'Demais eixos', fuel_percentage: 20, activated_at: nil) }

    it 'keeps the group of the tenant' do
      expect { expect(described_class.call(tenant, fuel_percentage: 33)).to eq(truck_group) }.not_to change(TruckGroup, :count)
      expect(truck_group.reload.fuel_percentage).to eq(20)
    end
  end
end
