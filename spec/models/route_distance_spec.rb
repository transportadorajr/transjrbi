require 'rails_helper'

RSpec.describe RouteDistance do
  let!(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the customer, the route and a positive distance' do
      route_distance = described_class.new(tenant:, distance_km: 0)

      expect(route_distance).not_to be_valid
      expect(route_distance.errors.attribute_names).to include(:customer_code, :origin_city, :origin_state, :destination_city,
                                                               :destination_state, :distance_km)
    end

    it 'does not accept the same route twice for the customer' do
      create(:route_distance, tenant:, customer_code: 7001)

      expect(build(:route_distance, tenant:, customer_code: 7001)).not_to be_valid
      expect(build(:route_distance, tenant:, customer_code: 7002)).to be_valid
      expect(build(:route_distance, tenant:, customer_code: 7001, destination_city: 'PORTO ALEGRE')).to be_valid
    end
  end

  describe '.normalize_city' do
    it 'removes accents, extra spaces and upcases the name' do
      expect(described_class.normalize_city('  São  José dos Pinhais ')).to eq('SAO JOSE DOS PINHAIS')
    end
  end

  describe '#route_key' do
    it 'matches the key of a transport document written differently' do
      route_distance = build(:route_distance, customer_code: 7001, origin_city: 'IPATINGA', destination_city: 'CAXIAS DO SUL')

      expect(route_distance.route_key).to eq(described_class.route_key(7001, 'Ipatinga', 'mg', 'Caxias  do Sul', 'rs'))
    end
  end

  describe 'scopes' do
    let!(:customer) { create(:atua_customer, tenant:, code: 7001) }
    let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001) }
    let!(:other_route) do
      create(:route_distance, tenant:, customer_code: 7002, origin_city: 'SERRA', origin_state: 'ES', destination_city: 'CURITIBA',
                              destination_state: 'PR')
    end

    it 'filters by customer, origin and destination' do
      expect(described_class.by_customer(7001)).to eq([route_distance])
      expect(described_class.by_origin('ipatin')).to eq([route_distance])
      expect(described_class.by_destination('curitiba')).to eq([other_route])
    end

    it 'counts the transport documents linked to each route' do
      create_list(:atua_transport_document, 2, tenant:, route_distance:)

      counts = described_class.with_documents_count.to_h { |route| [route.id, route.documents_count] }
      expect(counts).to eq(route_distance.id => 2, other_route.id => 0)
    end

    it 'sorts by the customer name' do
      create(:atua_customer, tenant:, code: 7002, name: 'AÇO VERDE DO BRASIL')

      expect(described_class.sorted_by(:customer_name, :asc)).to eq([other_route, route_distance])
    end
  end
end
