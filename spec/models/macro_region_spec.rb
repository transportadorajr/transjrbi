require 'rails_helper'

RSpec.describe MacroRegion do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH') }

    it 'requires a name unique by tenant and a two letter state' do
      region = build(:macro_region, tenant:, name: 'GRANDE BH', state: 'Minas', city_names: [])

      expect(region).not_to be_valid
      expect(region.errors.full_messages).to contain_exactly('Nome já está em uso', 'UF não é válido')
    end

    it 'accepts the same name in another tenant' do
      expect(build(:macro_region, name: 'GRANDE BH')).to be_valid
    end
  end

  describe 'cities' do
    let!(:region) { create(:macro_region, tenant:) }

    it 'keeps the cities without a region when the region is removed' do
      expect { region.destroy! }.not_to change(City, :count)

      expect(City.where(tenant:).pluck(:macro_region_id).uniq).to eq([nil])
    end
  end

  describe '#covers_city?' do
    let(:region) { build(:macro_region, city_names: ['Timóteo', "Pingo-d'Água"]) }

    it 'ignores accents, case, spaces and punctuation' do
      expect(region.covers_city?('TIMOTEO')).to be(true)
      expect(region.covers_city?('PINGO D AGUA')).to be(true)
    end

    it 'does not cover a city out of the list or a blank city' do
      expect(region.covers_city?('IPATINGA')).to be(false)
      expect(region.covers_city?(nil)).to be(false)
    end
  end

  describe '.for_origin' do
    let(:vale_do_aco) { build(:macro_region, tenant:) }
    let(:sao_paulo) { build(:macro_region, :sao_paulo, tenant:) }
    let(:interior) { build(:macro_region, :interior_sp, tenant:) }
    let(:regions) { [vale_do_aco, sao_paulo, interior] }

    it 'finds the region that lists the city in the same state' do
      expect(described_class.for_origin(regions, 'IPATINGA', 'MG')).to eq(vale_do_aco)
      expect(described_class.for_origin(regions, 'CUBATAO', 'sp')).to eq(sao_paulo)
    end

    it 'falls back to the region of the remaining state' do
      expect(described_class.for_origin(regions, 'PIRACICABA', 'SP')).to eq(interior)
    end

    it 'finds no region for a city of another state or out of every list' do
      expect(described_class.for_origin(regions, 'IPATINGA', 'SP')).to eq(interior)
      expect(described_class.for_origin(regions, 'JUIZ DE FORA', 'MG')).to be_nil
      expect(described_class.for_origin(regions, 'CASCAVEL', 'PR')).to be_nil
    end
  end

  describe '.unassigned_origins' do
    let(:vale_do_aco) { create(:macro_region, tenant:) }

    before do
      create_list(:atua_transport_document, 2, tenant:, origin_city: 'CASCAVEL', origin_state: 'PR')
      create(:atua_transport_document, tenant:, origin_city: 'MARINGA', origin_state: 'PR')
      create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG', origin_macro_region: vale_do_aco)
      create(:atua_transport_document, tenant:, origin_city: 'LONDRINA', origin_state: 'PR', vehicle_sale: true)
      create(:atua_transport_document, tenant:, origin_city: nil, origin_state: nil)
      create(:atua_transport_document, tenant: create(:tenant), origin_city: 'TOLEDO', origin_state: 'PR')
    end

    it 'counts the freight documents of the tenant whose origin is in no macro region' do
      expect(described_class.unassigned_origins(tenant)).to eq([[%w[CASCAVEL PR], 2], [%w[MARINGA PR], 1]])
    end
  end
end
