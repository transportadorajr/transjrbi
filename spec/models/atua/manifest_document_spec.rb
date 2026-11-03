require 'rails_helper'

RSpec.describe Atua::ManifestDocument do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with the manifest and transport documents of the tenant' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_236) }
      let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'JR TRANSPORTES') }
      let!(:document) do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES')
      end

      before do
        create(:atua_manifest, tenant: other_tenant, code: 41_236)
        create(:atua_transport_document, tenant:, number: '74130', series: 0, branch_name: 'JR TRANSPORTES')
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'TRANSJR SABARA')
        create(:atua_transport_document, tenant: other_tenant, number: '74130', series: 1, branch_name: 'JR TRANSPORTES')
      end

      it 'links the manifest by code inside the tenant' do
        expect(document.manifest).to eq(manifest)
      end

      it 'links the transport document by number, series and branch inside the tenant' do
        expect(document.transport_document).to eq(transport_document)
        expect(Atua::TransportDocument.count).to eq(4)
      end
    end
  end

  describe 'validations' do
    context 'with a document already imported' do
      let!(:document) { create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: 1) }

      it 'rejects the same document twice in the same manifest' do
        duplicated = build(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: 1)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:transport_document_number]).to eq(['já está em uso'])
      end

      it 'accepts the same document in another manifest' do
        expect(build(:atua_manifest_document, tenant:, manifest_code: 41_237, transport_document_number: document.transport_document_number)).to be_valid
      end
    end
  end

  describe 'database uniqueness' do
    context 'with a document without series already imported' do
      let!(:document) { create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: nil) }

      it 'does not store the same document without series twice in the same manifest' do
        duplicated = document.attributes.except('id', 'created_at', 'updated_at')

        expect { described_class.insert_all([duplicated]) }.not_to change(described_class, :count)
        expect { described_class.insert_all!([duplicated]) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe 'money' do
    it 'exposes the freight as reais' do
      expect(build(:atua_manifest_document, freight_cents: 321_720).freight).to eq(Money.from_cents(321_720, 'BRL'))
    end
  end

  describe '#loaded_km and #per_km' do
    it 'uses the greatest of the calculated and the document distances' do
      document = build(:atua_manifest_document, calculated_distance_km: BigDecimal('200'), document_distance_km: BigDecimal('180'))

      expect(document.loaded_km).to eq(BigDecimal('200'))
      expect(document.per_km(55_504)).to eq(Money.from_cents(278, 'BRL'))
    end

    it 'returns no value per km without a distance' do
      document = build(:atua_manifest_document, calculated_distance_km: nil, document_distance_km: BigDecimal('0'))

      expect(document.loaded_km).to be_nil
      expect(document.per_km(55_504)).to be_nil
    end

    it 'returns no value per km without an amount' do
      expect(build(:atua_manifest_document, document_distance_km: BigDecimal('100')).per_km(nil)).to be_nil
    end
  end

  describe '#gross_cents' do
    let!(:document) do
      create(:atua_manifest_document, tenant:, manifest_code: 41_520, transport_document_number: '74130', transport_document_series: 1,
                                      branch_name: 'JR', freight_cents: 321_720)
    end

    it 'uses the freight of the manifest document when the transport document was not imported' do
      expect(document.gross_cents).to eq(321_720)
    end

    it 'uses the freight of the transport document' do
      create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'JR', freight_cents: 55_504)

      expect(document.reload.gross_cents).to eq(55_504)
    end

    it 'returns no freight for a canceled transport document' do
      create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'JR', canceled_at: Time.current)

      expect(document.reload.gross_cents).to be_nil
    end
  end
end
