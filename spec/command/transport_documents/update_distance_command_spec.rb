require 'rails_helper'

RSpec.describe TransportDocuments::UpdateDistanceCommand do
  let!(:tenant) { create(:tenant) }

  def document_on_route(**attributes)
    create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                     destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1300'),
                                     **attributes)
  end

  context 'with a document carrying the distance from Atua' do
    let!(:document) { document_on_route }

    it 'replaces the distance keeping the distance from Atua' do
      freeze_time do
        described_class.call(document, BigDecimal('1420.5'))

        expect(document.reload).to have_attributes(distance_km: BigDecimal('1420.5'), original_distance_km: BigDecimal('1300'),
                                                   route_distance_id: nil, distance_adjusted_at: Time.current, distance_edited_at: Time.current)
      end
    end

    it 'changes nothing when the same distance is saved again' do
      described_class.call(document, BigDecimal('1420.5'))
      edited_at = document.reload.distance_edited_at

      travel 1.hour do
        described_class.call(document, BigDecimal('1420.5'))
      end

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1420.5'), original_distance_km: BigDecimal('1300'),
                                                 distance_edited_at: edited_at)
    end

    it 'keeps the distance from Atua when the distance is edited twice' do
      described_class.call(document, BigDecimal('1420.5'))
      described_class.call(document, BigDecimal('1500'))

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1500'), original_distance_km: BigDecimal('1300'))
    end

    it 'changes nothing when the distance is cleared without being edited' do
      described_class.call(document, nil)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: nil, distance_adjusted_at: nil,
                                                 distance_edited_at: nil)
    end
  end

  context 'with a document carrying the distance of a route' do
    let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1450')) }
    let!(:document) { document_on_route }

    before { RouteDistances::ApplyCommand.call(tenant) }

    it 'replaces the distance of the route keeping the distance from Atua' do
      described_class.call(document, BigDecimal('1380'))

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1380'), original_distance_km: BigDecimal('1300'), route_distance_id: nil)
      expect(document.distance_edited_at).to be_present
    end

    it 'goes back to the distance of the route when the distance is cleared' do
      described_class.call(document, BigDecimal('1380'))
      described_class.call(document, nil)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'),
                                                 route_distance_id: route_distance.id, distance_edited_at: nil)
    end
  end

  context 'with a document edited by hand that is not on a route' do
    let!(:document) do
      document_on_route(distance_km: BigDecimal('1380'), original_distance_km: BigDecimal('1300'), distance_adjusted_at: 1.day.ago,
                        distance_edited_at: 1.day.ago)
    end

    it 'goes back to the distance from Atua when the distance is cleared' do
      described_class.call(document, nil)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: nil, distance_adjusted_at: nil,
                                                 distance_edited_at: nil)
    end
  end
end
