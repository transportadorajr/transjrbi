require 'rails_helper'

RSpec.describe Atua::ReprocessImportCommand do
  let(:tenant) { create(:tenant) }
  let(:period) { { start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13) } }

  context 'with an import that already has its file attached' do
    let!(:import) { Atua::ImportReportCommand.call(tenant, :manifests, file: atua_fixture_path(:manifests), **period).sole }

    before do
      allow(Atua::Client).to receive(:new)
      tenant.atua_manifests.find_by!(code: 41_236).destroy!
      tenant.atua_manifest_documents.where(manifest_code: 41_236).delete_all
    end

    it 'reads the attached file again without downloading it' do
      described_class.call(import)

      expect(Atua::Client).not_to have_received(:new)
      expect(import.reload).to have_attributes(status_type: 'succeeded', rows_read: 390, inserted_count: 1, updated_count: 216, removed_count: 0)
      expect(tenant.atua_manifests.count).to eq(217)
      expect(tenant.atua_manifest_documents.count).to eq(390)
      expect(Atua::Import.count).to eq(1)
    end
  end

  context 'with a failed import' do
    let(:import) do
      create(:atua_import, tenant:, report_type: 'manifests', status_type: 'failed', error_message: 'Timeout', finished_at: 1.day.ago, **period)
    end

    before { import.file.attach(io: atua_fixture_path(:manifests).open, filename: 'manifests.xls') }

    it 'clears the previous error and imports the file' do
      described_class.call(import)

      expect(import.reload).to have_attributes(status_type: 'succeeded', error_message: nil, inserted_count: 217)
      expect(import.finished_at).to be > 1.minute.ago
    end
  end

  context 'with an import without a file' do
    let(:import) { create(:atua_import, tenant:, report_type: 'manifests', status_type: 'succeeded', inserted_count: 5) }

    it 'records the failure in the import' do
      described_class.call(import)

      expect(import.reload).to have_attributes(
        status_type: 'failed', inserted_count: 0, error_message: "A importação #{import.id} não tem arquivo anexado para ler.",
      )
    end
  end
end
