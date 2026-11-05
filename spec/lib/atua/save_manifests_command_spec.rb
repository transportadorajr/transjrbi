require 'rails_helper'

RSpec.describe Atua::SaveManifestsCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'manifests', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:manifests) }

  context 'with documents of an imported manifest that are no longer in the file' do
    let!(:stale) { create(:atua_manifest_document, tenant:, manifest_code: 41_239, transport_document_number: '1') }
    let!(:other_manifest) { create(:atua_manifest_document, tenant:, manifest_code: 1, transport_document_number: '1') }

    it 'replaces the documents of the imported manifests only' do
      result = described_class.call(import, spreadsheet)

      expect(result).to have_attributes(inserted: 217, updated: 0, removed: 0, warning: nil)
      expect(Atua::ManifestDocument.exists?(stale.id)).to be(false)
      expect(other_manifest.reload).to be_present
      expect(tenant.atua_manifest_documents.count).to eq(391)
    end
  end

  context 'with a manifest of an excluded plate in the file' do
    let!(:first_record) { Atua::MapManifestsCommand.call(tenant, spreadsheet).first }

    before do
      allow(Atua::MapManifestsCommand).to receive(:call).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).map { |attributes| attributes[:code] == first_record[:code] ? attributes.merge(plate: 'BAM2A26') : attributes }
      end
    end

    it 'leaves the manifest and its documents out of the active ones' do
      described_class.call(import, spreadsheet)

      expect(tenant.atua_manifests.find_by!(code: first_record[:code]).removed_from_atua_at).to be_present
      expect(tenant.atua_manifest_documents.active.where(manifest_code: first_record[:code])).to be_empty
    end
  end

  context 'with a manifest of the period that is no longer in the file' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 1) }
    let!(:document) { create(:atua_manifest_document, tenant:, manifest_code: 1, transport_document_number: '1') }

    it 'marks the manifest and its documents as removed' do
      result = described_class.call(import, spreadsheet)

      expect(result.removed).to eq(1)
      expect(manifest.reload.removed_from_atua_at).to be_present
      expect(document.reload.removed_from_atua_at).to be_present
    end
  end
end
