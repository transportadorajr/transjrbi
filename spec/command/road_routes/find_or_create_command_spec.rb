require 'rails_helper'

RSpec.describe RoadRoutes::FindOrCreateCommand do
  let(:client) { instance_double(Tomtom::Client) }
  let!(:origin) { create(:location, lookup_key: '|IPATINGA|MG') }
  let!(:destination) { create(:location, lookup_key: '|BETIM|MG', city: 'Betim') }

  before { allow(client).to receive(:route).and_return(Tomtom::Route.new(distance_meters: 217_436, travel_time_seconds: 10_820)) }

  it 'asks TomTom and stores a route that does not exist yet' do
    expect { described_class.call(origin, destination, client:) }.to change(RoadRoute, :count).by(1)

    expect(RoadRoute.last).to have_attributes(origin:, destination:, distance_km: BigDecimal('217.44'), travel_time_seconds: 10_820)
    expect(client).to have_received(:route).with(origin, destination)
  end

  context 'when the route is already stored' do
    let!(:route) { create(:road_route, origin:, destination:, distance_km: BigDecimal('210')) }

    it 'reuses it without asking TomTom' do
      expect { expect(described_class.call(origin, destination, client:)).to eq(route) }.not_to change(RoadRoute, :count)
      expect(client).not_to have_received(:route)
    end
  end

  context 'when an address fell back to a stored city center' do
    let!(:unmatched_address) do
      create(:location, lookup_key: 'RUA X 1|BETIM|MG', street: 'RUA X 1', latitude: destination.latitude, longitude: destination.longitude)
    end
    let!(:route) { create(:road_route, origin:, destination:) }

    it 'reuses the route of the city center' do
      expect(described_class.call(origin, unmatched_address, client:)).to eq(route)
      expect(client).not_to have_received(:route)
    end
  end
end
