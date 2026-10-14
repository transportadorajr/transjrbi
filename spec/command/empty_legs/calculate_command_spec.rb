require 'rails_helper'

RSpec.describe EmptyLegs::CalculateCommand do
  let(:client) { instance_double(Tomtom::Client) }
  let(:places) do
    {
      'RUA DAS FLORES 10, BETIM, MG' => place(-19.9681, -44.1979, 'Point Address', 'Betim'),
      'AVENIDA JOAO CESAR 500, CONTAGEM, MG' => place(-19.9320, -44.0539, 'Point Address', 'Contagem'),
    }
  end
  let!(:tenant) { create(:tenant) }
  let!(:recipient) { create(:atua_customer, tenant:, code: 501, street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG') }
  let!(:sender) { create(:atua_customer, tenant:, code: 502, street: 'AVENIDA JOAO CESAR 500', city: 'CONTAGEM', state: 'MG') }
  let!(:previous_trip) { trip(41_100, Time.zone.local(2026, 10, 1, 8)) }
  let!(:next_trip) { trip(41_200, Time.zone.local(2026, 10, 3, 8)) }

  def place(latitude, longitude, kind, city)
    Tomtom::Place.new(latitude:, longitude:, kind:, city:, state: 'MG', formatted_address: city)
  end

  def trip(code, started_at, **attributes)
    create(:atua_manifest, tenant:, code:, plate: 'RHJ4E07', branch_name: 'JR TRANSPORTES', trip_started_at: started_at, **attributes)
  end

  def transport_document(manifest, number, issued_at:, **attributes)
    create(:atua_transport_document, tenant:, number:, branch_name: 'JR TRANSPORTES', issued_at:, **attributes)
    create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                    branch_name: 'JR TRANSPORTES')
  end

  before do
    allow(client).to receive(:geocode) { |query, **| Array(places[query]) }
    allow(client).to receive(:route).and_return(Tomtom::Route.new(distance_meters: 23_450, travel_time_seconds: 1_800))

    transport_document(previous_trip, '74001', issued_at: Time.zone.local(2026, 10, 1, 7), origin_city: 'IPATINGA', origin_state: 'MG',
                                               destination_city: 'SAO PAULO', destination_state: 'SP')
    transport_document(previous_trip, '74002', issued_at: Time.zone.local(2026, 10, 1, 9), recipient_code: 501, origin_city: 'IPATINGA',
                                               origin_state: 'MG', destination_city: 'BETIM', destination_state: 'MG')
    transport_document(next_trip, '74003', issued_at: Time.zone.local(2026, 10, 3, 7), sender_code: 502, origin_city: 'CONTAGEM',
                                           origin_state: 'MG', destination_city: 'VITORIA', destination_state: 'ES')
  end

  it 'measures from the last delivery of the previous trip to the first pickup of the next one' do
    leg = nil

    expect { leg = described_class.call(next_trip, client:) }.to change(EmptyLeg, :count).by(1).and change(RoadRoute, :count).by(1)

    expect(leg).to have_attributes(
      tenant:, plate: 'RHJ4E07', previous_manifest_code: 41_100, next_manifest_code: 41_200, distance_km: BigDecimal('23.45'),
      precision_type: 'address', status_type: 'calculated', road_route: RoadRoute.last
    )
    expect(leg.origin).to have_attributes(street: 'RUA DAS FLORES 10', city: 'BETIM', precision_type: 'address')
    expect(leg.destination).to have_attributes(street: 'AVENIDA JOAO CESAR 500', city: 'CONTAGEM', precision_type: 'address')
  end

  it 'reuses the stored route and keeps a single leg when calculated again' do
    described_class.call(next_trip, client:)

    expect { described_class.call(next_trip, client:) }.not_to change(EmptyLeg, :count)
    expect(RoadRoute.count).to eq(1)
    expect(client).to have_received(:route).once
  end

  it 'links the empty leg to every freight of the next trip' do
    transport_document(next_trip, '74004', issued_at: Time.zone.local(2026, 10, 3, 9), origin_city: 'CONTAGEM', origin_state: 'MG')

    leg = described_class.call(next_trip, client:)

    expect(leg.transport_documents.pluck(:number)).to contain_exactly('74003', '74004')
    expect(EmptyLegTransportDocument.count).to eq(2)
  end

  it 'follows the freights of the next trip when calculated again' do
    leg = described_class.call(next_trip, client:)
    Atua::ManifestDocument.find_by!(transport_document_number: '74003').update!(removed_from_atua_at: Time.current)
    transport_document(next_trip, '74005', issued_at: Time.zone.local(2026, 10, 3, 10), origin_city: 'CONTAGEM', origin_state: 'MG')
    places['CONTAGEM, MG'] = place(-19.9386, -44.0529, 'Geography', 'Contagem')

    described_class.call(next_trip, client:)

    expect(leg.reload.transport_documents.pluck(:number)).to eq(['74005'])
  end

  it 'has no empty leg for the first trip of the plate' do
    expect { expect(described_class.call(previous_trip, client:)).to be_nil }.not_to change(EmptyLeg, :count)
  end

  context 'when the customer is registered in another city than the transport document' do
    before do
      sender.update!(city: 'BELO HORIZONTE')
      places['CONTAGEM, MG'] = place(-19.9386, -44.0529, 'Geography', 'Contagem')
    end

    it 'uses the city center of the transport document' do
      leg = described_class.call(next_trip, client:)

      expect(leg.destination).to have_attributes(street: nil, city: 'CONTAGEM', precision_type: 'city')
      expect(leg.precision_type).to eq('city')
    end
  end

  context 'when the address cannot be located' do
    before { places.delete('AVENIDA JOAO CESAR 500, CONTAGEM, MG') }

    it 'stores the leg as unlocated without distance' do
      leg = described_class.call(next_trip, client:)

      expect(leg).to have_attributes(status_type: 'unlocated', distance_km: nil, destination: nil, road_route: nil)
      expect(client).not_to have_received(:route)
    end
  end

  context 'when TomTom finds no route' do
    before { allow(client).to receive(:route).and_raise(Tomtom::NoRouteError) }

    it 'stores the leg as unrouted' do
      expect(described_class.call(next_trip, client:)).to have_attributes(status_type: 'unrouted', distance_km: nil, road_route: nil)
    end
  end

  context 'when the next pickup happens where the previous trip delivered' do
    before { sender.update!(street: 'RUA DAS FLORES 10', city: 'BETIM') }

    it 'counts no empty kilometers without asking for a route' do
      Atua::TransportDocument.find_by!(number: '74003').update!(origin_city: 'BETIM')

      expect(described_class.call(next_trip, client:)).to have_attributes(distance_km: 0, road_route: nil, status_type: 'calculated')
      expect(client).not_to have_received(:route)
    end
  end

  context 'when the next trip is canceled after its leg was calculated' do
    before { described_class.call(next_trip, client:) }

    it 'removes the leg and its freight links' do
      next_trip.update!(status: 'Cancelado')

      expect { described_class.call(next_trip, client:) }.to change(EmptyLeg, :count).by(-1).and change(EmptyLegTransportDocument, :count).by(-1)
    end
  end
end
