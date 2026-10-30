require 'rails_helper'

RSpec.describe TruckGroups::CreateUtingaAndFiveAxlesCommand do
  let(:tenant) { create(:tenant) }

  context 'without the groups' do
    it 'creates the group of the Utinga plates and the group of 5 axles' do
      expect { described_class.call(tenant) }.to change(TruckGroup, :count).by(2)

      expect(tenant.truck_groups.find_by!(name: 'Utinga')).to have_attributes(
        axles: [], plates: %w[BAV5A04 BCN1A44 BEC3D14 EVO8C24 EVU4D57], fuel_percentage: BigDecimal('28'), activated?: true,
      )
      expect(tenant.truck_groups.find_by!(name: '5 eixos')).to have_attributes(
        axles: [5], plates: [], fuel_percentage: BigDecimal('35'), activated?: true,
      )
    end

    it 'does not duplicate the groups when it runs again' do
      first_result = described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(first_result) }.not_to change(TruckGroup, :count)
    end
  end

  context 'when the groups were changed on the screen' do
    let!(:utinga) { create(:truck_group, tenant:, name: 'Utinga', axles: [], plates: %w[BAV5A04], fuel_percentage: 30) }
    let!(:five_axles) { create(:truck_group, tenant:, name: '5 eixos', axles: [5], fuel_percentage: 40) }

    it 'keeps the changes' do
      expect { expect(described_class.call(tenant)).to eq([utinga, five_axles]) }.not_to change(TruckGroup, :count)

      expect(utinga.reload).to have_attributes(plates: %w[BAV5A04], fuel_percentage: BigDecimal('30'))
      expect(five_axles.reload.fuel_percentage).to eq(BigDecimal('40'))
    end
  end

  context 'when another active group already has 5 axles' do
    let!(:bitrem) { create(:truck_group, tenant:, name: 'Bitrem', axles: [4, 5]) }

    it 'keeps that group instead of creating a conflicting one' do
      expect(described_class.call(tenant).last).to eq(bitrem)
      expect(tenant.truck_groups.pluck(:name)).to contain_exactly('Bitrem', 'Utinga')
    end
  end
end
