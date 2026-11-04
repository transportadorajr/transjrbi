require 'rails_helper'

RSpec.describe DistanceAdjustments::ApplyCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450')) }

  context 'when the transport document is already imported' do
    let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }
    let!(:other_document) { create(:atua_transport_document, tenant:, number: '74121', distance_km: BigDecimal('300')) }
    let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74120', distance_km: BigDecimal('300')) }

    it 'replaces the distance of the document keeping the distance from Atua' do
      freeze_time do
        expect(described_class.call(adjustment)).to eq(1)

        expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'),
                                                   distance_adjusted_at: Time.current)
        expect(adjustment.reload.applied_at).to eq(Time.current)
      end
      expect(other_document.reload).to have_attributes(distance_km: BigDecimal('300'), distance_adjusted_at: nil)
      expect(stranger.reload).to have_attributes(distance_km: BigDecimal('300'), distance_adjusted_at: nil)
    end

    it 'keeps the distance from Atua when it runs again' do
      described_class.call(adjustment)
      applied_at = adjustment.reload.applied_at

      travel 1.hour do
        expect(described_class.call(adjustment)).to eq(1)
      end

      expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
      expect(adjustment.reload.applied_at).to eq(applied_at)
    end

    it 'replaces the distance again when the adjustment changes' do
      described_class.call(adjustment)
      adjustment.update!(distance_km: BigDecimal('520'))

      described_class.call(adjustment)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('520'), original_distance_km: BigDecimal('300'))
    end
  end

  context 'when two transport documents share the number' do
    let!(:first) { create(:atua_transport_document, tenant:, number: '74120', series: 1, distance_km: BigDecimal('300')) }
    let!(:second) { create(:atua_transport_document, tenant:, number: '74120', series: 2, distance_km: BigDecimal('280')) }

    it 'adjusts both documents' do
      expect(described_class.call(adjustment)).to eq(2)

      expect(first.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
      expect(second.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('280'))
    end
  end

  context 'when the transport document was not imported yet' do
    it 'keeps the adjustment waiting for the document' do
      expect(described_class.call(adjustment)).to eq(0)

      expect(adjustment.reload.applied_at).to be_nil
    end
  end
end
