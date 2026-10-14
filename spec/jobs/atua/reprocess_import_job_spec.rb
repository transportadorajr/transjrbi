require 'rails_helper'

RSpec.describe Atua::ReprocessImportJob do
  let!(:tenant) { create(:tenant) }
  let!(:import) { create(:atua_import, :with_file, tenant:, report_type: 'manifests', status_type: 'failed') }

  before { allow(Atua::ReprocessImportCommand).to receive(:call).and_return(import) }

  it 'reprocesses the import' do
    described_class.perform_now(import.id)

    expect(Atua::ReprocessImportCommand).to have_received(:call).with(import)
  end

  it 'shares the label of the imports of the same tenant and report' do
    expect(described_class.new(import.id).good_job_labels).to eq(["atua-import:#{tenant.id}:manifests"])
  end

  context 'with the GoodJob adapter' do
    before { use_good_job_adapter(described_class, Atua::ImportReportJob) }

    it 'waits while an import of the same report of the tenant is running' do
      mark_good_job_running(Atua::ImportReportJob.perform_later(tenant.id, 'manifests', Date.new(2026, 10, 1), Date.new(2026, 10, 13)))
      waiting = described_class.perform_later(import.id)

      GoodJob.perform_inline

      expect(Atua::ReprocessImportCommand).not_to have_received(:call)
      expect(good_job_record(waiting).finished_at).to be_nil
    end
  end
end
