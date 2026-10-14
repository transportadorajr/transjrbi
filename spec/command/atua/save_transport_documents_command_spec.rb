require 'rails_helper'

RSpec.describe Atua::SaveTransportDocumentsCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'transport_documents', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:transport_documents) }

  context 'with a manifest link of an imported document that is no longer in the file' do
    let!(:stale) { create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '1') }

    it 'replaces the manifest links with the manifest numbers of the file' do
      result = described_class.call(import, spreadsheet)

      expect(result).to have_attributes(inserted: 420, updated: 0, removed: 0)
      expect(Atua::TransportDocumentManifest.exists?(stale.id)).to be(false)
      expect(tenant.atua_transport_document_manifests.where(transport_document_code: 80_842).pluck(:manifest_number, :branch_name, :raw_data))
        .to eq([['183', 'EMPRESA 01', { 'nr_mdfe' => 183.0 }]])
    end
  end
end
