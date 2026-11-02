require 'rails_helper'

RSpec.describe Atua::DiscardExcludedPlatesCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with records of an excluded plate and of a fleet plate' do
    let!(:excluded_document) { create(:atua_transport_document, tenant:, plate: 'BAM2A26') }
    let!(:fleet_document) { create(:atua_transport_document, tenant:, plate: 'RHJ4E07') }
    let!(:excluded_trailer_document) { create(:atua_transport_document, tenant:, plate: 'RHJ4E07', trailer_plate: 'BAM2A26') }
    let!(:document_link) { create(:atua_transport_document_manifest, tenant:, transport_document_code: excluded_document.code, manifest_number: '1') }
    let!(:freight_expense) { create(:freight_expense, tenant:, transport_document: excluded_document) }
    let!(:document_expense) do
      create(:atua_expense, tenant:, transport_document_code: excluded_document.code, cost_object: excluded_document)
    end
    let!(:excluded_manifest) { create(:atua_manifest, tenant:, plate: 'BAM2A26') }
    let!(:fleet_manifest) { create(:atua_manifest, tenant:, plate: 'RHJ4E07') }
    let!(:manifest_document) { create(:atua_manifest_document, tenant:, manifest_code: excluded_manifest.code, transport_document_number: '1') }
    let!(:excluded_expense) { create(:atua_expense, tenant:, plate: 'BAM2A26') }
    let!(:excluded_toll_voucher) { create(:atua_toll_voucher, tenant:, plate: 'BAM2A26') }
    let!(:fleet_toll_voucher) { create(:atua_toll_voucher, tenant:, plate: 'RHJ4E07') }
    let!(:excluded_vehicle) { create(:atua_vehicle, tenant:, plate: 'BAM2A26') }
    let!(:fleet_vehicle) { create(:atua_vehicle, tenant:, plate: 'RHJ4E07') }

    it 'removes every record of the excluded plate, with the links and freight expenses of its documents' do
      expect(described_class.call(tenant)).to eq(5)

      expect(tenant.atua_transport_documents.active).to contain_exactly(fleet_document, excluded_trailer_document)
      expect(document_link.reload.removed_from_atua_at).to be_present
      expect(FreightExpense.exists?(freight_expense.id)).to be(false)
      expect(document_expense.reload.cost_object_id).to be_nil
      expect(tenant.atua_manifests.active).to contain_exactly(fleet_manifest)
      expect(manifest_document.reload.removed_from_atua_at).to be_present
      expect(tenant.atua_expenses.active).to contain_exactly(document_expense)
      expect(tenant.atua_toll_vouchers.active).to contain_exactly(fleet_toll_voucher)
      expect(tenant.atua_vehicles.active).to contain_exactly(fleet_vehicle)
    end

    it 'finds nothing left on a second run' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'when another tenant has a document of the excluded plate' do
    let!(:document) { create(:atua_transport_document, tenant: other_tenant, plate: 'BAM2A26') }

    it 'keeps the document of the other tenant' do
      expect(described_class.call(tenant)).to eq(0)
      expect(document.reload.removed_from_atua_at).to be_nil
    end
  end
end
