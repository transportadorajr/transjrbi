require 'rails_helper'

RSpec.describe Atua::Customer do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with transport documents and expenses of the tenant' do
      let!(:customer) { create(:atua_customer, tenant:, code: 7752) }
      let!(:sent) { create(:atua_transport_document, tenant:, sender_code: 7752) }
      let!(:received) { create(:atua_transport_document, tenant:, recipient_code: 7752) }
      let!(:paid) { create(:atua_transport_document, tenant:, payer_code: 7752, taker_code: 7752) }
      let!(:consigned) { create(:atua_transport_document, tenant:, consignee_code: 7752) }
      let!(:expense) { create(:atua_expense, tenant:, payee_code: 7752) }

      before do
        create(:atua_transport_document, tenant: other_tenant, sender_code: 7752, payer_code: 7752)
        create(:atua_expense, tenant: other_tenant, payee_code: 7752)
      end

      it 'lists the transport documents of each role inside the tenant' do
        expect(customer.sent_transport_documents).to eq([sent])
        expect(customer.received_transport_documents).to eq([received])
        expect(customer.paid_transport_documents).to eq([paid])
        expect(customer.taken_transport_documents).to eq([paid])
        expect(customer.consigned_transport_documents).to eq([consigned])
        expect(Atua::TransportDocument.count).to eq(5)
      end

      it 'lists the expenses paid to the customer inside the tenant' do
        expect(customer.expenses).to eq([expense])
      end
    end
  end

  describe 'validations' do
    context 'with a customer already imported' do
      let!(:customer) { create(:atua_customer, tenant:, code: 294) }

      it 'rejects the same code in the same tenant' do
        duplicated = build(:atua_customer, tenant:, code: 294)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:atua_customer, tenant: other_tenant, code: customer.code)).to be_valid
      end
    end
  end

  describe 'scopes' do
    context 'with customers of different names and documents' do
      let!(:steel) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.', trade_name: nil, document_digits: '17469701006612') }
      let!(:warehouse) { create(:atua_customer, tenant:, name: '100-TL ARMAZENS GERAIS LTDA.', trade_name: 'TL ARMAZENS', document_digits: '10622725000175') }
      let!(:removed) { create(:atua_customer, tenant:, name: 'METAL WIRE', document_digits: '08968756000130', removed_from_atua_at: Time.current) }

      it 'filters by name or trade name ignoring case' do
        expect(described_class.by_name('arcelor')).to eq([steel])
        expect(described_class.by_name('tl armazens')).to eq([warehouse])
        expect(described_class.count).to eq(3)
      end

      it 'filters by the document digits' do
        expect(described_class.by_document('10.622.725/0001-75')).to eq([warehouse])
      end

      it 'filters by city ignoring case' do
        steel.update!(city: 'JOAO MONLEVADE')
        warehouse.update!(city: 'IPATINGA')
        removed.update!(city: 'BETIM')

        expect(described_class.by_city('monlevade')).to eq([steel])
      end

      it 'keeps out customers removed from Atua' do
        expect(described_class.active).to contain_exactly(steel, warehouse)
        expect(described_class.removed_from_atua).to eq([removed])
      end
    end
  end
end
