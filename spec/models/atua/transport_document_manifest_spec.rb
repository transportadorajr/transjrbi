require 'rails_helper'

RSpec.describe Atua::TransportDocumentManifest do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with the transport document and the manifest of the tenant' do
      let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_842) }
      let!(:manifest) { create(:atua_manifest, tenant:, number: '40798', branch_name: 'JR TRANSPORTES') }
      let!(:link) do
        create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '40798',
                                                  branch_name: 'JR TRANSPORTES')
      end

      before do
        create(:atua_transport_document, tenant: other_tenant, code: 80_842)
        create(:atua_manifest, tenant:, number: '40798', branch_name: 'TRANSJR SABARA')
      end

      it 'links the transport document by code inside the tenant' do
        expect(link.transport_document).to eq(transport_document)
      end

      it 'links the manifest by number and branch' do
        expect(link.manifest).to eq(manifest)
        expect(Atua::Manifest.count).to eq(2)
      end
    end
  end

  describe 'validations' do
    context 'with a link already imported' do
      let!(:link) { create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '40798') }

      it 'rejects the same manifest twice for the transport document' do
        duplicated = build(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '40798')

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:manifest_number]).to eq(['já está em uso'])
      end

      it 'accepts another manifest for the transport document' do
        expect(build(:atua_transport_document_manifest, tenant:, transport_document_code: link.transport_document_code, manifest_number: '40834')).to be_valid
      end
    end
  end
end
