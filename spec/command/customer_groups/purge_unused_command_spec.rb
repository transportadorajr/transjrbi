require 'rails_helper'

RSpec.describe CustomerGroups::PurgeUnusedCommand do
  let(:tenant) { create(:tenant) }
  let(:group) { create(:customer_group, tenant:, name: 'SEM USO') }
  let!(:customer) { create(:atua_customer, tenant:, code: 1, customer_group: group) }

  context 'when the tenant has no transport documents loaded' do
    it 'keeps the group' do
      expect(described_class.call(tenant)).to eq(0)
      expect(customer.reload.customer_group).to eq(group)
    end
  end

  context 'when no customer of the group took a recent transport document' do
    before { create(:atua_transport_document, tenant:, taker_code: 1, issued_at: 13.months.ago) }

    it 'removes the group, keeps the customer and can run again' do
      expect(described_class.call(tenant)).to eq(1)

      expect(CustomerGroup.exists?(group.id)).to be(false)
      expect(customer.reload.customer_group_id).to be_nil
      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'when a customer of the group took a recent transport document' do
    before { create(:atua_transport_document, tenant:, taker_code: 1, issued_at: 1.month.ago) }

    it 'keeps the group' do
      described_class.call(tenant)

      expect(customer.reload.customer_group).to eq(group)
    end
  end

  context 'when the customer is only the sender of a recent transport document' do
    before { create(:atua_transport_document, tenant:, sender_code: 1, taker_code: 2, issued_at: 1.month.ago) }

    it 'removes the group' do
      described_class.call(tenant)

      expect(customer.reload.customer_group_id).to be_nil
    end
  end

  context 'when the unused group has terms or rules' do
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

  context 'when a group was just created and has no customers yet' do
    let!(:empty_group) { create(:customer_group, tenant:, name: 'NOVO') }

    before { create(:atua_transport_document, tenant:, taker_code: 1, issued_at: 1.month.ago) }

    it 'keeps it' do
      described_class.call(tenant)

      expect(CustomerGroup.exists?(empty_group.id)).to be(true)
    end
  end
end
