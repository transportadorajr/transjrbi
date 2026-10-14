require 'rails_helper'

RSpec.describe Tomtom::Client do
  let(:client) { described_class.new(api_key: 'test-key') }
  let(:origin) { build(:location, latitude: BigDecimal('-19.4685'), longitude: BigDecimal('-42.5367')) }
  let(:destination) { build(:location, latitude: BigDecimal('-19.9678'), longitude: BigDecimal('-44.1983')) }
  let(:geocode_url) { %r{\Ahttps://api\.tomtom\.com/search/2/geocode/} }
  let(:route_url) { 'https://api.tomtom.com/routing/1/calculateRoute/-19.4685,-42.5367:-19.9678,-44.1983/json' }
  let(:geocode_body) do
    {
      results: [
        {
          type: 'Point Address', position: { lat: -19.9681, lon: -44.1979 },
          address: { municipality: 'Betim', countrySubdivisionCode: 'MG', freeformAddress: 'Rua das Flores, 10, Betim' }
        },
      ],
    }.to_json
  end

  describe '#geocode' do
    it 'returns the places found in Brazil' do
      stub_request(:get, geocode_url).to_return(status: 200, body: geocode_body)

      places = client.geocode('Rua das Flores 10, Betim, MG')

      expect(places).to eq(
        [
          Tomtom::Place.new(latitude: -19.9681, longitude: -44.1979, kind: 'Point Address', city: 'Betim', state: 'MG',
                            formatted_address: 'Rua das Flores, 10, Betim'),
        ],
      )
      expect(WebMock).to have_requested(:get, 'https://api.tomtom.com/search/2/geocode/Rua%20das%20Flores%2010%2C%20Betim%2C%20MG.json')
        .with(query: { key: 'test-key', countrySet: 'BR', language: 'pt-BR', limit: '5' })
    end

    it 'restricts the search to municipalities when asked' do
      stub_request(:get, geocode_url).to_return(status: 200, body: geocode_body)

      client.geocode('Betim, MG', municipality: true)

      expect(WebMock).to have_requested(:get, geocode_url).with(query: hash_including(entityTypeSet: 'Municipality'))
    end

    it 'returns no place when nothing is found' do
      stub_request(:get, geocode_url).to_return(status: 200, body: { results: [] }.to_json)

      expect(client.geocode('Lugar Nenhum, MG')).to eq([])
    end

    it 'raises a rate limit error when the quota is exceeded' do
      stub_request(:get, geocode_url).to_return(status: 429, body: '')

      expect { client.geocode('Betim, MG') }.to raise_error(Tomtom::RateLimitError) { |error| expect(error.status).to eq(429) }
    end

    it 'raises a request error on a bad request' do
      stub_request(:get, geocode_url).to_return(status: 400, body: '')

      expect { client.geocode('Betim, MG') }.to raise_error(Tomtom::RequestError, 'O TomTom respondeu HTTP 400.')
    end

    it 'raises a request error when the network fails' do
      stub_request(:get, geocode_url).to_timeout

      expect { client.geocode('Betim, MG') }.to raise_error(Tomtom::RequestError, /A requisição para o TomTom em .* falhou/)
    end
  end

  describe '#route' do
    it 'returns the truck route distance and travel time' do
      stub_request(:get, route_url).with(query: hash_including(travelMode: 'truck', vehicleNumberOfAxles: '6', key: 'test-key'))
        .to_return(status: 200, body: { routes: [{ summary: { lengthInMeters: 217_436, travelTimeInSeconds: 10_820 } }] }.to_json)

      route = client.route(origin, destination)

      expect(route).to eq(Tomtom::Route.new(distance_meters: 217_436, travel_time_seconds: 10_820))
      expect(route.distance_km).to eq(BigDecimal('217.44'))
    end

    it 'raises a no route error when the points cannot be connected' do
      stub_request(:get, route_url).with(query: hash_including({})).to_return(status: 400, body: { error: 'NO_ROUTE_FOUND' }.to_json)

      expect { client.route(origin, destination) }.to raise_error(Tomtom::NoRouteError, 'O TomTom não encontrou rota entre os dois pontos.')
    end
  end

  it 'hides the api key when inspected' do
    expect(client.inspect).not_to include('test-key')
  end

  describe 'Tomtom.api_key' do
    it 'raises a configuration error without the key in the credentials' do
      allow(Rails.application.credentials).to receive(:dig).with(:tomtom, :api_key).and_return(nil)

      expect { Tomtom.api_key }.to raise_error(Tomtom::ConfigurationError, /falta tomtom\.api_key/)
    end
  end
end
