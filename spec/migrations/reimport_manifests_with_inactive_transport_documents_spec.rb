require 'rails_helper'
require Rails.root.join('db/migrate/20261104005921_reimport_manifests_with_inactive_transport_documents')

RSpec.describe ReimportManifestsWithInactiveTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a manifest whose transport document was removed from Atua', flipper: :atua_import do
    let!(:tenant) { create(:tenant) }
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 8, 10, 9), removed_from_atua_at: Time.current)
    end

    before do
      manifest = create(:atua_manifest, tenant:, issued_on: Date.new(2026, 8, 10))
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
    end

    it 'schedules the reimport of the month' do
      expect { migration.up }.to have_enqueued_job(Atua::ImportReportJob)
        .with(tenant.id, 'transport_documents', Date.new(2026, 8, 1), Date.new(2026, 8, 31))
    end
  end
end
