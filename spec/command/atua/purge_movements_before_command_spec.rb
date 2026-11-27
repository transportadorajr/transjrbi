require 'rails_helper'

RSpec.describe Atua::PurgeMovementsBeforeCommand do
  let!(:tenant) { create(:tenant) }

  context 'with manifests, transport documents and expenses on both sides of the cutoff' do
    let!(:old_manifest) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 3, 31)) }
    let!(:new_manifest) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 4, 1)) }
    let!(:old_document) { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 3, 31, 23, 59)) }
    let!(:new_document) { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 4, 1, 0, 1)) }
    let!(:old_expense) { create(:atua_expense, tenant:, posted_on: Date.new(2026, 3, 31)) }
    let!(:new_expense) { create(:atua_expense, tenant:, posted_on: Date.new(2026, 4, 1)) }
    let!(:old_leg) { create(:empty_leg, tenant:, previous_manifest_code: old_manifest.code, next_manifest_code: new_manifest.code) }
    let!(:other_tenant_manifest) { create(:atua_manifest, tenant: create(:tenant), issued_on: Date.new(2026, 3, 1)) }

    before do
      create(:atua_manifest_document, tenant:, manifest_code: old_manifest.code, transport_document_number: old_document.number)
      create(:atua_manifest_document, tenant:, manifest_code: new_manifest.code, transport_document_number: old_document.number)
      create(:atua_transport_document_manifest, tenant:, transport_document_code: old_document.code, manifest_number: new_manifest.number)
      create(:atua_transport_document_manifest, tenant:, transport_document_code: new_document.code, manifest_number: new_manifest.number)
      create(:freight_expense, tenant:, transport_document: old_document)
      create(:freight_expense, tenant:, transport_document: new_document)
      create(:empty_leg_transport_document, tenant:, empty_leg: old_leg, transport_document_code: old_document.code)
    end

    it 'deletes only what was issued or posted before the cutoff' do
      expect { described_class.call(tenant) }.to have_enqueued_job(EmptyLegs::CalculateJob).with(tenant.id, nil)

      expect(Atua::Manifest.all).to contain_exactly(new_manifest, other_tenant_manifest)
      expect(Atua::TransportDocument.all).to eq([new_document])
      expect(Atua::Expense.all).to eq([new_expense])
      expect(Atua::ManifestDocument.pluck(:manifest_code)).to eq([new_manifest.code])
      expect(Atua::TransportDocumentManifest.pluck(:transport_document_code)).to eq([new_document.code])
      expect(FreightExpense.pluck(:transport_document_id)).to eq([new_document.id])
      expect(EmptyLeg.count).to eq(0)
      expect(EmptyLegTransportDocument.count).to eq(0)
    end

    it 'returns the number of manifests, transport documents and expenses deleted' do
      expect(described_class.call(tenant)).to eq(3)
    end

    it 'deletes nothing when run again' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to have_enqueued_job(EmptyLegs::CalculateJob)
      expect(Atua::Manifest.where(tenant:)).to eq([new_manifest])
    end
  end

  context 'with a cutoff given by the caller' do
    let!(:document) { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 4, 15, 10)) }

    it 'deletes the records before that date' do
      expect(described_class.call(tenant, Date.new(2026, 5, 1))).to eq(1)
      expect(Atua::TransportDocument.count).to eq(0)
    end
  end
end
