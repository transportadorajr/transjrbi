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

  it 'does not link the expenses after importing manifests' do
    expect { described_class.call(import) }.not_to have_enqueued_job(Atua::LinkExpensesJob)
  end

  %w[expenses transport_documents vehicles].each do |report_type|
    context "when importing #{report_type}" do
      let(:import) { create(:atua_import, tenant:, report_type:, status_type: 'running', started_at: Time.current) }

      before { import.file.attach(io: atua_fixture_path(report_type).open, filename: "#{report_type}.xls") }

      it 'links the expenses of the tenant to their freights and vehicles' do
        expect { described_class.call(import) }.to have_enqueued_job(Atua::LinkExpensesJob).with(tenant.id)
      end
    end
  end

  context 'when saving the expenses fails' do
    let(:import) { create(:atua_import, tenant:, report_type: 'expenses', status_type: 'running', started_at: Time.current) }

    before do
      import.file.attach(io: atua_fixture_path(:expenses).open, filename: 'expenses.xls')
      allow(Atua::Expense).to receive(:upsert_all).and_raise(ActiveRecord::StatementInvalid, 'PG::Error: connection lost')
    end

    it 'does not link the expenses' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::LinkExpensesJob)

      expect(import.reload.status_type).to eq('failed')
    end
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
