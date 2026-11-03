require 'rails_helper'

RSpec.describe MacroRegions::AssignRemainingStateCommand do
  let(:tenant) { create(:tenant) }

  context 'with cities without a macro region' do
    let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
    let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: ['Cascavel']) }
    let!(:londrina) { create(:city, tenant:, name: 'Londrina', state: 'PR') }
    let!(:maringa) { create(:city, tenant:, name: 'Maringá', state: 'PR') }
    let!(:cubatao) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }
    let!(:buenos_aires) { create(:city, tenant:, name: 'Buenos Aires', state: 'EX') }
    let!(:stranger_city) { create(:city, tenant: create(:tenant), name: 'Londrina', state: 'PR') }

    it 'creates the remaining state region of a state that has none and keeps the existing one' do
      expect { expect(described_class.call(tenant)).to eq(3) }.to change(MacroRegion, :count).by(1)

      resto_parana = tenant.macro_regions.find_by!(state: 'PR', remaining_state: true)
      expect(resto_parana.name).to eq('RESTO DO PARANÁ')
      expect(resto_parana.cities).to contain_exactly(londrina, maringa)
      expect(cubatao.reload.macro_region).to eq(interior)
      expect(oeste_parana.cities.map(&:name)).to eq(['Cascavel'])
    end

    it 'leaves the foreign cities and the cities of another tenant without a macro region' do
      described_class.call(tenant)

      expect(buenos_aires.reload.macro_region).to be_nil
      expect(stranger_city.reload.macro_region).to be_nil
    end

    it 'can run again without creating another region' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to change(MacroRegion, :count)
    end
  end
end
