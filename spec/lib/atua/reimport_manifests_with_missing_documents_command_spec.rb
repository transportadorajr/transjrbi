require 'rails_helper'

RSpec.describe Atua::ReimportManifestsWithMissingDocumentsCommand do
  let!(:tenant) { create(:tenant) }

  def create_trip(number, issued_on: Date.new(2026, 8, 10), **attributes)
    manifest = create(:atua_manifest, tenant:, issued_on:, **attributes)
    create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                    branch_name: 'JR TRANSPORTES')
    manifest
  end

  context 'when a manifest points to a transport document that was not imported' do
    before { create_trip('69674') }

    it 'reimports the transport documents and manifests of the month of the manifest and of the month before it' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(4).times

      [Date.new(2026, 7, 1), Date.new(2026, 8, 1)].each do |month|
        %w[transport_documents manifests].each do |report_type|
          expect(Atua::ImportReportJob).to have_been_enqueued.with(tenant.id, report_type, month, month.end_of_month)
        end
      end
    end
  end

  context 'when several manifests of the same month point to missing transport documents' do
    before do
      create_trip('69674')
      create_trip('69675', issued_on: Date.new(2026, 8, 20))
    end

    it 'reimports each month once per report' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(4).times
    end
  end

  context 'when the month before the manifest is before the purge cutoff' do
    before { create_trip('68895', issued_on: Date.new(2026, 4, 1)) }

    it 'reimports only the months from the cutoff on' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(2).times
      expect(Atua::ImportReportJob).to have_been_enqueued.with(tenant.id, 'transport_documents', Date.new(2026, 4, 1), Date.new(2026, 4, 30))
    end
  end

  context 'when the transport document exists only in another series' do
    before do
      create(:atua_transport_document, tenant:, number: '69674', series: 50, branch_name: 'JR TRANSPORTES')
      create_trip('69674')
    end

    it 'reimports the months of the manifest' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(4).times
    end
  end

  context 'when every transport document of the manifests was imported' do
    before do
      create(:atua_transport_document, tenant:, number: '69674', series: 1, branch_name: 'JR TRANSPORTES', removed_from_atua_at: Time.current)
      create_trip('69674')
    end

    it 'reimports nothing' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the manifest is canceled' do
    before { create_trip('69674', status: Atua::Manifest::CANCELED_STATUS) }

    it 'reimports nothing' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the manifest document was removed from Atua' do
    before { create_trip('69674').documents.update_all(removed_from_atua_at: Time.current) }

    it 'reimports nothing' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the missing transport document belongs to another tenant' do
    before do
      other_tenant = create(:tenant)
      manifest = create(:atua_manifest, tenant: other_tenant, issued_on: Date.new(2026, 8, 10))
      create(:atua_manifest_document, tenant: other_tenant, manifest_code: manifest.code, transport_document_number: '69674')
    end

    it 'reimports nothing for the tenant' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end
end
