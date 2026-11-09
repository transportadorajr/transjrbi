require 'rails_helper'

RSpec.describe TransportDocumentDistanceForm do
  let!(:tenant) { create(:tenant) }
  let!(:document) { create(:atua_transport_document, tenant:, distance_km: BigDecimal('1300')) }

  describe '.for_transport_document' do
    it 'leaves the distance blank when it was not edited by hand' do
      expect(described_class.for_transport_document(document).distance_km).to be_nil
    end

    it 'fills the distance edited by hand' do
      document.update!(distance_km: BigDecimal('1420.5'), original_distance_km: BigDecimal('1300'), distance_adjusted_at: Time.current,
                       distance_edited_at: Time.current)

      expect(described_class.for_transport_document(document).distance_km).to eq('1420,50')
    end
  end

  describe '#save' do
    it 'saves a distance written with a decimal comma and a thousands separator' do
      form = described_class.new(transport_document: document, distance_km: ' 1.420,5 ')

      expect(form.save).to be(true)
      expect(document.reload).to have_attributes(distance_km: BigDecimal('1420.5'), original_distance_km: BigDecimal('1300'))
    end

    it 'goes back to the distance from Atua when the distance is blank' do
      described_class.new(transport_document: document, distance_km: '1420').save

      expect(described_class.new(transport_document: document, distance_km: '').save).to be(true)
      expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), distance_edited_at: nil)
    end

    it 'rejects a distance that is not positive' do
      form = described_class.new(transport_document: document, distance_km: '0')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['KM considerado deve ser maior que 0'])
      expect(document.reload.distance_edited_at).to be_nil
    end

    it 'rejects a distance that is not a number' do
      form = described_class.new(transport_document: document, distance_km: 'abc')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['KM considerado deve ser maior que 0'])
    end
  end
end
