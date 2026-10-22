require 'rails_helper'

RSpec.describe MacroRegion do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH') }

    it 'requires a name unique by tenant and a two letter state' do
      region = build(:macro_region, tenant:, name: 'GRANDE BH', state: 'Minas')

      expect(region).not_to be_valid
      expect(region.errors.full_messages).to contain_exactly('Nome já está em uso', 'UF não é válido')
    end

    it 'accepts the same name in another tenant' do
      expect(build(:macro_region, name: 'GRANDE BH')).to be_valid
    end
  end

  describe '#covers_city?' do
    let(:region) { build(:macro_region, cities: ['Timóteo', "Pingo-d'Água"]) }

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
end
