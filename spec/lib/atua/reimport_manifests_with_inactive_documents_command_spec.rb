require 'rails_helper'

RSpec.describe Atua::ReimportManifestsWithInactiveDocumentsCommand do
  let!(:tenant) { create(:tenant) }

  def create_trip(transport_document, issued_on: Date.new(2026, 8, 10))
    manifest = create(:atua_manifest, tenant:, issued_on:)
    create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
    manifest
  end

  context 'when a manifest points to a transport document removed from Atua' do
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 7, 31, 18), removed_from_atua_at: Time.current)
    end

    before { create_trip(transport_document) }

    it 'reimports the transport documents and manifests of the months involved' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(4).times

      [Date.new(2026, 7, 1), Date.new(2026, 8, 1)].each do |month|
        %w[transport_documents manifests].each do |report_type|
          expect(Atua::ImportReportJob).to have_been_enqueued.with(tenant.id, report_type, month, month.end_of_month)
        end
      end
    end
  end

  context 'when a manifest points to a canceled transport document' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 8, 10, 9), canceled_at: Time.current) }

    before { create_trip(transport_document) }

    it 'reimports the month once per report' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(2).times
    end
  end

  context 'when every transport document of the manifests is active' do
    before { create_trip(create(:atua_transport_document, tenant:)) }

    it 'reimports nothing' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the transport document was discarded for an excluded plate' do
    before { create_trip(create(:atua_transport_document, tenant:, plate: 'BAM2A26', removed_from_atua_at: Time.current)) }

    it 'reimports nothing' do
      expect { described_class.call(tenant) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the manifest is canceled' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, removed_from_atua_at: Time.current) }

    before { create_trip(transport_document).update!(status: Atua::Manifest::CANCELED_STATUS) }

    it 'reimports only the month of the transport document' do
      expect { described_class.call(tenant) }.to have_enqueued_job(Atua::ImportReportJob).exactly(2).times
    end
  end
end
