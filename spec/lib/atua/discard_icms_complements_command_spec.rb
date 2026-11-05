require 'rails_helper'

RSpec.describe Atua::DiscardIcmsComplementsCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with value complements of ICMS only, of freight and a normal document' do
    let!(:original) { create(:atua_transport_document, tenant:, number: '74754', freight_cents: 427_577, icms_cents: 45_577) }
    let!(:icms_complement) do
      create(:atua_transport_document, tenant:, number: '74777', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       complemented_transport_document: original, freight_cents: 6_514, icms_cents: 6_514)
    end
    let!(:icms_complement_without_freight) do
      create(:atua_transport_document, tenant:, number: '74381', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       freight_cents: nil, icms_cents: 4_844)
    end
    let!(:freight_complement) do
      create(:atua_transport_document, tenant:, number: '74778', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       complemented_transport_document: original, freight_cents: 73_600, icms_cents: 8_832)
    end
    let!(:complement_without_icms) do
      create(:atua_transport_document, tenant:, number: '74779', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       freight_cents: 0, icms_cents: 0)
    end
    let!(:normal_document_of_tax_only) { create(:atua_transport_document, tenant:, number: '74780', freight_cents: 6_514, icms_cents: 6_514) }
    let!(:other_tenant_complement) do
      create(:atua_transport_document, tenant: other_tenant, issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       freight_cents: 6_514, icms_cents: 6_514)
    end
    let!(:manifest_link) do
      create(:atua_transport_document_manifest, tenant:, transport_document_code: icms_complement.code, manifest_number: '1')
    end
    let!(:freight_expense) { create(:freight_expense, tenant:, transport_document: icms_complement) }

    it 'removes only the ICMS complements of the tenant, with their manifest links and freight expenses' do
      expect(described_class.call(tenant)).to eq(2)

      expect(tenant.atua_transport_documents.active)
        .to contain_exactly(original, freight_complement, complement_without_icms, normal_document_of_tax_only)
      expect(icms_complement_without_freight.reload.removed_from_atua_at).to be_present
      expect(manifest_link.reload.removed_from_atua_at).to be_present
      expect(FreightExpense.exists?(freight_expense.id)).to be(false)
      expect(other_tenant_complement.reload.removed_from_atua_at).to be_nil
    end

    it 'finds nothing left on a second run' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end
end
