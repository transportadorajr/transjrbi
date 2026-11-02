require 'rails_helper'

RSpec.describe TruckGroups::CreateSiderCommand do
  let(:tenant) { create(:tenant) }

  context 'with the LS group of 6 axles' do
    let!(:ls) { create(:truck_group, :ls, tenant:, name: 'LS', fuel_percentage: BigDecimal('33')) }

    before { ls.change_fuel_percentage(BigDecimal('31'), 1.month.ago.to_date.beginning_of_month) }

    it 'renames the LS group to 6 axles and creates the Sider group by plate with its fuel rates' do
      expect { described_class.call(tenant) }.to change(TruckGroup, :count).by(1)

      expect(ls.reload).to have_attributes(name: '6 eixos', axles: [6])
      sider = tenant.truck_groups.find_by!(name: 'Sider')
      expect(sider).to have_attributes(
        axles: [], plates: %w[BDZ8J90 RHJ3A99 RHJ4E07 RHJ5A51 RHL2C11 SFK0H59 UBL2C11], fuel_percentage: BigDecimal('33'), activated?: true,
      )
      expect(sider.fuel_rates.order(:valid_month).pluck(:valid_month, :percentage)).to eq(ls.fuel_rates.order(:valid_month).pluck(:valid_month, :percentage))
    end

    it 'does not duplicate the group when it runs again' do
      first_result = described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(first_result) }.not_to change(TruckGroup, :count)
      expect(tenant.truck_groups.pluck(:name)).to contain_exactly('6 eixos', 'Sider')
    end
  end

  context 'when the groups were changed on the screen' do
    let!(:sider) { create(:truck_group, tenant:, name: 'Sider', axles: [], plates: %w[RHJ5A51], fuel_percentage: 25) }

    before { create(:truck_group, tenant:, name: 'LS', axles: [6], activated_at: nil) }

    it 'keeps the changes' do
      expect { expect(described_class.call(tenant)).to eq([sider]) }.not_to change(TruckGroup, :count)

      expect(sider.reload).to have_attributes(plates: %w[RHJ5A51], fuel_percentage: BigDecimal('25'))
    end
  end

  context 'without a group of 6 axles' do
    it 'creates the Sider group without fuel' do
      expect(described_class.call(tenant).first).to have_attributes(name: 'Sider', fuel_percentage: 0)
    end
  end
end
