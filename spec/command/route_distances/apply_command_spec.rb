require 'rails_helper'

RSpec.describe RouteDistances::ApplyCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1450')) }

  def document_on_route(**attributes)
    create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                     destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1300'),
                                     **attributes)
  end

  context 'with documents of the customer on the route' do
    let!(:document) { document_on_route }
    let!(:other_route_document) { document_on_route(destination_city: 'PORTO ALEGRE') }
    let!(:other_customer_document) { document_on_route(taker_code: 7002) }
    let!(:stranger) { document_on_route(tenant: other_tenant) }

    it 'replaces the distance of the documents of the route keeping the distance from Atua' do
      freeze_time do
        expect(described_class.call(tenant)).to eq(1)

        expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'),
                                                   route_distance_id: route_distance.id, distance_adjusted_at: Time.current)
      end
      [other_route_document, other_customer_document, stranger].each do |untouched|
        expect(untouched.reload).to have_attributes(distance_km: BigDecimal('1300'), route_distance_id: nil, distance_adjusted_at: nil)
      end
    end

    it 'matches city names written with accents or another case' do
      written_differently = document_on_route(origin_city: 'Ipatinga', destination_city: 'Caxias do  Sul', destination_state: 'rs')

      described_class.call(tenant)

      expect(written_differently.reload).to have_attributes(distance_km: BigDecimal('1450'), route_distance_id: route_distance.id)
    end

    it 'changes nothing when it runs again' do
      described_class.call(tenant)
      adjusted_at = document.reload.distance_adjusted_at

      travel 1.hour do
        expect(described_class.call(tenant)).to eq(0)
      end

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'),
                                                 distance_adjusted_at: adjusted_at)
    end

    it 'replaces the distance again when the route changes' do
      described_class.call(tenant)
      route_distance.update!(distance_km: BigDecimal('1520'))

      expect(described_class.call(tenant)).to eq(1)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1520'), original_distance_km: BigDecimal('1300'))
    end
  end

  context 'with a document adjusted that no longer matches a route' do
    let!(:document) do
      create(:atua_transport_document, tenant:, taker_code: 7009, distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'),
                                       distance_adjusted_at: 1.day.ago)
    end

    it 'restores the distance from Atua' do
      expect(described_class.call(tenant)).to eq(1)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('300'), original_distance_km: nil, route_distance_id: nil,
                                                 distance_adjusted_at: nil)
    end
  end

  context 'with a document adjusted by another route of the customer' do
    let!(:previous_route) { create(:route_distance, tenant:, customer_code: 7001, destination_city: 'PORTO ALEGRE') }
    let!(:document) do
      document_on_route(distance_km: BigDecimal('900'), original_distance_km: BigDecimal('1300'), route_distance: previous_route,
                        distance_adjusted_at: 1.day.ago)
    end

    it 'moves the document to the matching route keeping the distance from Atua' do
      described_class.call(tenant)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'),
                                                 route_distance_id: route_distance.id)
    end
  end

  context 'with a document of the route whose distance was edited by hand' do
    let!(:document) do
      document_on_route(distance_km: BigDecimal('1380'), original_distance_km: BigDecimal('1300'), distance_adjusted_at: 1.day.ago,
                        distance_edited_at: 1.day.ago)
    end

    it 'keeps the distance edited by hand' do
      expect(described_class.call(tenant)).to eq(0)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1380'), original_distance_km: BigDecimal('1300'), route_distance_id: nil)
    end
  end
end
