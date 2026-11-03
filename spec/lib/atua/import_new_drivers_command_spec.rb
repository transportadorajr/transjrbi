require 'rails_helper'

RSpec.describe Atua::ImportNewDriversCommand, flipper: :atua_import do
  let!(:tenant) { create(:tenant) }
  let!(:import) { create(:atua_import, tenant:, report_type: 'transport_documents', status_type: 'succeeded') }

  context 'when a transport document of the import has a driver missing from the vehicle registry' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501, driver_name: 'JOAO NOVO') }

    it 'imports the vehicles of the tenant to pull the full driver registry from Atua' do
      expect { described_class.call(import) }.to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'vehicles').exactly(:once)
    end
  end

  context 'when the driver is in the registry without a document' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 501, driver_name: 'JOAO NOVO', driver_document: nil) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'imports the vehicles to complete the driver registry' do
      expect { described_class.call(import) }.to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'vehicles')
    end
  end

  context 'when the driver is already in the registry with a document' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 501, driver_name: 'JOAO', driver_document: '123.456.789-09') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the driver is only registered on a vehicle removed from Atua' do
    let!(:vehicle) do
      create(:atua_vehicle, tenant:, driver_code: 501, driver_document: '123.456.789-09', removed_from_atua_at: Time.current)
    end
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'imports the vehicles of the tenant' do
      expect { described_class.call(import) }.to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'vehicles')
    end
  end

  context 'when the vehicles were imported after the transport document first appeared' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501, created_at: 2.hours.ago) }
    let!(:vehicles_import) { create(:atua_import, tenant:, report_type: 'vehicles', start_date: nil, end_date: nil, created_at: 1.hour.ago) }

    it 'does not import the vehicles again for a driver Atua did not return' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the transport document first appeared after the last vehicles import' do
    let!(:vehicles_import) { create(:atua_import, tenant:, report_type: 'vehicles', start_date: nil, end_date: nil, created_at: 2.hours.ago) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501, created_at: 1.hour.ago) }

    it 'imports the vehicles of the tenant' do
      expect { described_class.call(import) }.to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'vehicles')
    end
  end

  context 'when the missing driver is excluded' do
    let!(:excluded_driver) { create(:excluded_driver, tenant:, code: 501) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the transport document with the missing driver is canceled' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501, canceled_at: Time.current) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the transport document with the missing driver belongs to another import' do
    let!(:other_import) { create(:atua_import, tenant:, report_type: 'transport_documents', status_type: 'succeeded') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import: other_import, driver_code: 501) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the import is not of transport documents' do
    let!(:import) { create(:atua_import, tenant:, report_type: 'manifests', status_type: 'succeeded') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end

  context 'when the Atua import is disabled for the tenant', flipper: nil do
    let!(:transport_document) { create(:atua_transport_document, tenant:, import:, driver_code: 501) }

    it 'does not import the vehicles' do
      expect { described_class.call(import) }.not_to have_enqueued_job(Atua::ImportReportJob)
    end
  end
end
