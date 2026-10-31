require 'rails_helper'

RSpec.describe Atua::PurgeInactiveCustomersCommand do
  let(:tenant) { create(:tenant) }
  let(:group) { create(:customer_group, tenant:, name: 'GRUPO INATIVO') }
  let!(:inactive) { create(:atua_customer, tenant:, code: 1, customer_group: group) }

  context 'when the tenant has no transport documents loaded' do
    it 'keeps every customer' do
      expect(described_class.call(tenant)).to eq(0)
      expect(tenant.atua_customers.count).to eq(1)
    end
  end

  context 'when a customer only has a transport document older than twelve months' do
    let!(:active) { create(:atua_customer, tenant:, code: 2) }

    before do
      create(:atua_transport_document, tenant:, taker_code: 1, sender_code: nil, recipient_code: nil, payer_code: nil, consignee_code: nil, issued_at: 13.months.ago)
      create(:atua_transport_document, tenant:, taker_code: 2, sender_code: nil, recipient_code: nil, payer_code: nil, consignee_code: nil, issued_at: 1.month.ago)
    end

    it 'removes the customer and its emptied group, and can run again' do
      expect(described_class.call(tenant)).to eq(1)

      expect(tenant.atua_customers.pluck(:id)).to eq([active.id])
      expect(CustomerGroup.exists?(group.id)).to be(false)
      expect(described_class.call(tenant)).to eq(0)
    end
  end

  %i[sender_code recipient_code payer_code taker_code consignee_code].each do |column|
    context "when the customer is the #{column} of a recent transport document" do
      before do
        attributes = { sender_code: nil, recipient_code: nil, payer_code: nil, taker_code: nil, consignee_code: nil }
        create(:atua_transport_document, tenant:, **attributes, column => 1, issued_at: 1.month.ago)
      end

      it 'keeps the customer' do
        expect { described_class.call(tenant) }.not_to change(Atua::Customer, :count)
      end
    end
  end

  context 'when a customer without recent transport documents has an internal document' do
    let!(:internal) { create(:atua_customer, tenant:, code: 2, document_digits: '10212838000364') }

    before { create(:atua_transport_document, tenant:, taker_code: 2, issued_at: 13.months.ago) }

    it 'keeps that customer so its transport documents stay discarded' do
      described_class.call(tenant)

      expect(tenant.atua_customers.pluck(:id)).to eq([internal.id])
    end
  end

  context 'when another customer still belongs to the group' do
    before do
      create(:atua_customer, tenant:, code: 2, customer_group: group)
      create(:atua_transport_document, tenant:, taker_code: 2, issued_at: 1.month.ago)
    end

    it 'keeps the group' do
      described_class.call(tenant)

      expect(CustomerGroup.exists?(group.id)).to be(true)
    end
  end

  context 'when the emptied group has terms or rules' do
    let!(:terms_group) { create(:customer_group, tenant:, name: 'COM TERMOS', terms: ['TERMO']) }
    let!(:commission_group) { create(:customer_group, tenant:, name: 'COM COMISSAO') }
    let!(:tonnage_group) { create(:customer_group, tenant:, name: 'COM TONELAGEM') }

    before do
      create(:atua_customer, tenant:, code: 3, customer_group: terms_group)
      create(:atua_customer, tenant:, code: 4, customer_group: commission_group)
      create(:atua_customer, tenant:, code: 5, customer_group: tonnage_group)
      create(:commission_rule, tenant:, customer_group: commission_group)
      create(:tonnage_rate, tenant:, customer_group: tonnage_group)
      create(:atua_transport_document, tenant:, issued_at: 13.months.ago)
    end

    it 'keeps those groups' do
      described_class.call(tenant)

      expect(tenant.customer_groups.pluck(:name)).to contain_exactly('COM TERMOS', 'COM COMISSAO', 'COM TONELAGEM')
    end
  end

  context 'when another tenant has an inactive customer' do
    let(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

    before do
      create(:atua_customer, tenant: other_tenant, code: 1)
      create(:atua_transport_document, tenant:, issued_at: 13.months.ago)
    end

    it 'does not touch it' do
      described_class.call(tenant)

      expect(other_tenant.atua_customers.count).to eq(1)
    end
  end
end
