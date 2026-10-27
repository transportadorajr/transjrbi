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
end
