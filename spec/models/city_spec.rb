require 'rails_helper'

RSpec.describe City do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    before { create(:city, tenant:, name: 'Ipatinga', state: 'MG') }

    it 'requires a name unique by tenant and state and a two letter state' do
      city = build(:city, tenant:, name: 'Ipatinga', state: 'MG')
      invalid_state = build(:city, tenant:, name: 'Betim', state: 'Minas')

      expect(city).not_to be_valid
      expect(city.errors.full_messages).to eq(['Nome já está em uso'])
      expect(invalid_state).not_to be_valid
      expect(invalid_state.errors.full_messages).to eq(['UF não é válido'])
    end

    it 'accepts the same name in another state or tenant' do
      expect(build(:city, tenant:, name: 'Ipatinga', state: 'SP')).to be_valid
      expect(build(:city, name: 'Ipatinga', state: 'MG')).to be_valid
    end
  end

  describe 'scopes' do
    let!(:vale_do_aco) { create(:macro_region, tenant:, city_names: ['Ipatinga']) }
    let!(:cubatao) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }

    it 'filters by name, state and macro region' do
      ipatinga = vale_do_aco.cities.first

      expect(described_class.by_name('ipat')).to eq([ipatinga])
      expect(described_class.by_state('sp')).to eq([cubatao])
      expect(described_class.by_macro_region(vale_do_aco.id)).to eq([ipatinga])
      expect(described_class.by_macro_region(MacroRegion::OTHERS)).to eq([cubatao])
    end
  end
end
