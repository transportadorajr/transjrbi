require 'rails_helper'

RSpec.describe Locations::FindOrCreateCommand do
  let(:client) { instance_double(Tomtom::Client) }
  let(:betim) { Tomtom::Place.new(latitude: -19.9678, longitude: -44.1983, kind: 'Geography', city: 'Betim', state: 'MG', formatted_address: 'Betim') }
  let(:street) do
    Tomtom::Place.new(latitude: -19.9681, longitude: -44.1979, kind: 'Point Address', city: 'Betim', state: 'MG',
                      formatted_address: 'Rua das Flores, 10, Betim')
  end

  context 'when the location is already stored' do
    let!(:location) { create(:location, lookup_key: 'RUA DAS FLORES 10|BETIM|MG') }

    before { allow(client).to receive(:geocode) }

    it 'returns it without asking TomTom' do
      expect(described_class.call(street: 'Rua das Flores, 10', city: 'BETIM', state: 'mg', client:)).to eq(location)
      expect(client).not_to have_received(:geocode)
    end
  end

  context 'when TomTom finds the street in the same city' do
    before { allow(client).to receive(:geocode).with('RUA DAS FLORES 10, BETIM, MG').and_return([street]) }

    it 'stores the address with address precision' do
      expect { described_class.call(street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG', client:) }.to change(Location, :count).by(1)

      expect(Location.last).to have_attributes(
        lookup_key: 'RUA DAS FLORES 10|BETIM|MG', street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG',
        latitude: BigDecimal('-19.9681'), longitude: BigDecimal('-44.1979'), precision_type: 'address',
        formatted_address: 'Rua das Flores, 10, Betim'
      )
    end
  end

  context 'when TomTom places the street in another city' do
    let(:elsewhere) { street.with(city: 'Contagem') }

    before do
      allow(client).to receive(:geocode).with('RUA ANONIMA 0377, BETIM, MG').and_return([elsewhere])
      allow(client).to receive(:geocode).with('RUA ANONIMA 0400, BETIM, MG').and_return([])
      allow(client).to receive(:geocode).with('BETIM, MG', municipality: true).and_return([betim])
    end

    it 'falls back to the city center and remembers the address' do
      expect { described_class.call(street: 'RUA ANONIMA 0377', city: 'BETIM', state: 'MG', client:) }.to change(Location, :count).by(2)

      city = Location.find_by!(lookup_key: '|BETIM|MG')
      address = Location.find_by!(lookup_key: 'RUA ANONIMA 0377|BETIM|MG')
      expect(city).to have_attributes(precision_type: 'city', latitude: BigDecimal('-19.9678'), longitude: BigDecimal('-44.1983'))
      expect(address).to have_attributes(precision_type: 'city', latitude: city.latitude, longitude: city.longitude)
    end

    it 'reuses the stored city center for another unmatched street' do
      described_class.call(street: 'RUA ANONIMA 0377', city: 'BETIM', state: 'MG', client:)

      expect { described_class.call(street: 'RUA ANONIMA 0400', city: 'BETIM', state: 'MG', client:) }.to change(Location, :count).by(1)
      expect(client).to have_received(:geocode).with('BETIM, MG', municipality: true).once
    end
  end

  context 'when TomTom lists a similar city first' do
    let(:pinhais) { betim.with(latitude: -25.4429, longitude: -49.1927, city: 'Pinhais', state: 'PR') }

    before do
      allow(client).to receive(:geocode).with('PINHAIS, PR', municipality: true).and_return([pinhais.with(city: 'São José dos Pinhais'), pinhais])
    end

    it 'picks the candidate of the same city' do
      expect(described_class.call(street: nil, city: 'PINHAIS', state: 'PR', client:))
        .to have_attributes(latitude: BigDecimal('-25.4429'), longitude: BigDecimal('-49.1927'))
    end
  end

  context 'when TomTom does not find the city' do
    before { allow(client).to receive(:geocode).with('CIDADE INEXISTENTE, MG', municipality: true).and_return([]) }

    it 'returns nothing and stores nothing' do
      expect { described_class.call(street: nil, city: 'CIDADE INEXISTENTE', state: 'MG', client:) }.not_to change(Location, :count)
    end
  end

  context 'without a city' do
    before { allow(client).to receive(:geocode) }

    it 'returns nothing without asking TomTom' do
      expect(described_class.call(street: 'RUA X', city: nil, state: 'MG', client:)).to be_nil
      expect(client).not_to have_received(:geocode)
    end
  end
end
