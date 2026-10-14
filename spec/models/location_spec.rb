require 'rails_helper'

RSpec.describe Location do
  describe '.lookup_key_for' do
    it 'normalizes accents, punctuation, case and spaces' do
      key = described_class.lookup_key_for(street: ' Rua São João,  10 ', city: "Santa Bárbara d'Oeste", state: 'sp')

      expect(key).to eq('RUA SAO JOAO 10|SANTA BARBARA D OESTE|SP')
    end

    it 'leaves the street part empty for a city' do
      expect(described_class.lookup_key_for(street: nil, city: 'Betim', state: 'MG')).to eq('|BETIM|MG')
    end
  end

  describe 'validations' do
    it 'requires a unique lookup key' do
      create(:location, lookup_key: '|BETIM|MG')
      location = build(:location, lookup_key: '|BETIM|MG')

      expect(location).not_to be_valid
      expect(location.errors[:lookup_key]).to be_present
    end

    it 'requires the coordinates' do
      location = build(:location, latitude: nil, longitude: nil)

      expect(location).not_to be_valid
      expect(location.errors.attribute_names).to include(:latitude, :longitude)
    end

    it 'rejects an unknown precision' do
      expect(build(:location, precision_type: 'street')).not_to be_valid
    end
  end

  describe '#canonical' do
    let!(:city) { create(:location, lookup_key: '|BETIM|MG', latitude: BigDecimal('-19.9678'), longitude: BigDecimal('-44.1983')) }
    let!(:unmatched_address) do
      create(:location, lookup_key: 'RUA X 1|BETIM|MG', street: 'RUA X 1', latitude: city.latitude, longitude: city.longitude)
    end

    it 'returns the oldest location at the same coordinates' do
      expect(unmatched_address.canonical).to eq(city)
      expect(city.canonical).to eq(city)
    end
  end

  describe '#same_place?' do
    it 'compares the coordinates' do
      location = build(:location, latitude: BigDecimal('-19.1'), longitude: BigDecimal('-42.1'))

      expect(location.same_place?(build(:location, latitude: BigDecimal('-19.1'), longitude: BigDecimal('-42.1')))).to be(true)
      expect(location.same_place?(build(:location, latitude: BigDecimal('-19.2'), longitude: BigDecimal('-42.1')))).to be(false)
    end
  end
end
