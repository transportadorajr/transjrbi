require 'rails_helper'

RSpec.describe Atua::DiscardInternalTakerDocumentsCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with documents taken by each Transjr CNPJ and by a customer' do
    let!(:internal_customers) do
      Atua::TransportDocument::INTERNAL_TAKER_DOCUMENTS.map { |document_digits| create(:atua_customer, tenant:, document_digits:) }
    end
    let!(:customer) { create(:atua_customer, tenant:) }
    let!(:internal_documents) { internal_customers.map { |taker| create(:atua_transport_document, tenant:, taker_code: taker.code) } }
    let!(:billed_document) { create(:atua_transport_document, tenant:, taker_code: customer.code) }
    let!(:internal_payer_document) do
      create(:atua_transport_document, tenant:, taker_code: customer.code, payer_document_digits: '10212838000100')
    end
    let!(:manifest_link) do
      create(:atua_transport_document_manifest, tenant:, transport_document_code: internal_documents.first.code, manifest_number: '1')
    end
    let!(:freight_expense) { create(:freight_expense, tenant:, transport_document: internal_documents.first) }
    let!(:expense) do
      create(:atua_expense, tenant:, transport_document_code: internal_documents.first.code, cost_object: internal_documents.first)
    end

    it 'removes only the documents with a Transjr taker, with their links and freight expenses' do
      expect(described_class.call(tenant)).to eq(6)

      expect(tenant.atua_transport_documents.active).to contain_exactly(billed_document, internal_payer_document)
      expect(manifest_link.reload.removed_from_atua_at).to be_present
      expect(FreightExpense.exists?(freight_expense.id)).to be(false)
      expect(expense.reload.cost_object_id).to be_nil
    end

    it 'finds nothing left on a second run' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'when another tenant has a customer with the code of the taker and a Transjr CNPJ' do
    let!(:stranger) { create(:atua_customer, tenant: other_tenant, code: 501, document_digits: '10212838000100') }
    let!(:customer) { create(:atua_customer, tenant:, code: 501) }
    let!(:document) { create(:atua_transport_document, tenant:, taker_code: 501) }

    it 'keeps the document of the tenant' do
      expect(described_class.call(tenant)).to eq(0)
      expect(document.reload.removed_from_atua_at).to be_nil
    end
  end
end
