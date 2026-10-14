require 'rails_helper'

RSpec.describe Atua::ProcessImportCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'manifests', status_type: 'running', started_at: Time.current) }

  before { import.file.attach(io: atua_fixture_path(:manifests).open, filename: 'manifests.xls') }

  it 'saves the records of the attached file and finishes the import' do
    described_class.call(import)

    expect(import.reload).to have_attributes(status_type: 'succeeded', rows_read: 390, inserted_count: 217, updated_count: 0)
    expect(tenant.atua_manifests.count).to eq(217)
  end

  it 'calculates the empty legs from the start of the imported period' do
    expect { described_class.call(import) }.to have_enqueued_job(EmptyLegs::CalculateJob).with(tenant.id, '2026-10-01')
  end

  context 'when saving fails halfway' do
    before do
      allow(Atua::ManifestDocument).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'PG::Error: connection lost')
    end

    it 'rolls back everything saved from the file and records the failure' do
      described_class.call(import)

      expect(import.reload).to have_attributes(status_type: 'failed', error_message: 'PG::Error: connection lost', inserted_count: 0)
      expect(tenant.atua_manifests.count).to eq(0)
      expect(tenant.atua_manifest_documents.count).to eq(0)
    end

    it 'does not calculate the empty legs' do
      expect { described_class.call(import) }.not_to have_enqueued_job(EmptyLegs::CalculateJob)
    end
  end
end
