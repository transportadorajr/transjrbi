require 'rails_helper'

RSpec.describe DistanceAdjustmentForm do
  let!(:tenant) { create(:tenant) }

  describe '#save' do
    context 'when the transport document is already imported' do
      let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }

      it 'creates the adjustment and replaces the distance of the document' do
        form = described_class.new(tenant:, transport_document_number: '074120', distance_km: '1.450,50')

        expect { form.save }.to change(DistanceAdjustment, :count).by(1)

        adjustment = DistanceAdjustment.last
        expect(adjustment).to have_attributes(tenant:, transport_document_number: '74120', distance_km: BigDecimal('1450.5'))
        expect(adjustment.applied_at).to be_present
        expect(form.documents_count).to eq(1)
        expect(document.reload).to have_attributes(distance_km: BigDecimal('1450.5'), original_distance_km: BigDecimal('300'))
      end
    end

    context 'when the transport document was not imported yet' do
      it 'creates the adjustment waiting for the document' do
        form = described_class.new(tenant:, transport_document_number: '74999', distance_km: '610')

        expect { form.save }.to change(DistanceAdjustment, :count).by(1)

        expect(DistanceAdjustment.last.applied_at).to be_nil
        expect(form.documents_count).to eq(0)
      end
    end

    context 'when the number of an applied adjustment changes' do
      let!(:old_document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }
      let!(:new_document) { create(:atua_transport_document, tenant:, number: '74121', distance_km: BigDecimal('280')) }
      let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450')) }

      before { DistanceAdjustments::ApplyCommand.call(adjustment) }

      it 'gives the old document its distance back and adjusts the new one' do
        form = described_class.for_distance_adjustment(adjustment)
        form.assign_attributes(transport_document_number: '74121', distance_km: '450,00')

        expect(form.save).to be(true)

        expect(adjustment.reload).to have_attributes(transport_document_number: '74121', distance_km: BigDecimal('450'))
        expect(old_document.reload).to have_attributes(distance_km: BigDecimal('300'), original_distance_km: nil, distance_adjusted_at: nil)
        expect(new_document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('280'))
      end
    end

    context 'with invalid values' do
      it 'requires the number and the distance' do
        form = described_class.new(tenant:, transport_document_number: '', distance_km: '')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Número do CT-e não pode ficar em branco', 'KM considerado não pode ficar em branco'])
      end

      it 'rejects a number with letters and a distance that is not positive' do
        form = described_class.new(tenant:, transport_document_number: 'CT74120', distance_km: '0')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Número do CT-e não é válido', 'KM considerado deve ser maior que 0'])
      end

      it 'rejects a number that already has an adjustment' do
        create(:distance_adjustment, tenant:, transport_document_number: '74120')
        form = described_class.new(tenant:, transport_document_number: '74120', distance_km: '450')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Número do CT-e já tem um ajuste de km cadastrado'])
      end
    end
  end
end
