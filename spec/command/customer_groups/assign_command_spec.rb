require 'rails_helper'

RSpec.describe CustomerGroups::AssignCommand do
  let(:tenant) { create(:tenant) }

  context 'when the customers match the terms of a group' do
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM', 'TERRAFEC', 'TERRINHA ALIMENTOS']) }
    let!(:first_customer) { create(:atua_customer, tenant:, name: '2JM COMERCIO DE ALIMENTOS LTDA') }
    let!(:second_customer) { create(:atua_customer, tenant:, name: 'DISTRIBUIDORA BH LTDA', trade_name: 'Terrinha Alimentos') }

    it 'links every matching customer to the group' do
      expect { expect(described_class.call(tenant)).to eq(2) }.not_to change(CustomerGroup, :count)

      expect(first_customer.reload.customer_group).to eq(food)
      expect(second_customer.reload.customer_group).to eq(food)
    end
  end

  context 'when only the taker name on the transport documents matches the terms of a group' do
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:customer) { create(:atua_customer, tenant:, code: 6260, name: 'PESSOA 04263', trade_name: 'PESSOA 04264') }
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, taker_code: 6260, taker_name: 'USINAS SIDERURGICAS DE MINAS GERAIS S\\A - USIMINAS')
    end

    it 'links the customer to the group' do
      expect { expect(described_class.call(tenant)).to eq(1) }.not_to change(CustomerGroup, :count)

      expect(customer.reload.customer_group).to eq(usiminas)
    end
  end

  context 'when transport documents are loaded and a customer took none recently' do
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['TERRAFEC']) }
    let!(:matching) { create(:atua_customer, tenant:, code: 1, name: 'TERRAFEC LTDA') }
    let!(:recent_taker) { create(:atua_customer, tenant:, code: 2, name: 'TOMADOR RECENTE') }
    let!(:former_taker) { create(:atua_customer, tenant:, code: 3, name: 'TOMADOR ANTIGO') }

    before do
      create(:atua_transport_document, tenant:, taker_code: 2, issued_at: 1.month.ago)
      create(:atua_transport_document, tenant:, taker_code: 3, issued_at: 13.months.ago)
    end

    it 'creates an own group only for the recent taker and still applies the terms' do
      expect { described_class.call(tenant) }.to change(CustomerGroup, :count).by(1)

      expect(matching.reload.customer_group).to eq(food)
      expect(recent_taker.reload.customer_group.name).to eq('TOMADOR RECENTE')
      expect(former_taker.reload.customer_group_id).to be_nil
    end
  end

  context 'when a customer matches no terms' do
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['TERRAFEC']) }
    let!(:first_branch) { create(:atua_customer, tenant:, name: ' USIMINAS  S.A. ') }
    let!(:second_branch) { create(:atua_customer, tenant:, name: 'USIMINAS S.A.') }
    let!(:unnamed) { create(:atua_customer, tenant:, code: 9001, name: nil, trade_name: nil) }

    it 'creates an active group named after the customer and shares it among customers with the same name' do
      expect { described_class.call(tenant) }.to change(CustomerGroup, :count).by(2)

      own_group = tenant.customer_groups.find_by!(name: 'USIMINAS S.A.')
      expect(own_group.terms).to eq([])
      expect(own_group).to be_activated
      expect(first_branch.reload.customer_group).to eq(own_group)
      expect(second_branch.reload.customer_group).to eq(own_group)
      expect(unnamed.reload.customer_group.name).to eq('Cliente 9001')
    end
  end

  context 'when a customer already has a group' do
    let!(:manual_group) { create(:customer_group, tenant:, name: 'MANUAL') }
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['TERRAFEC']) }
    let!(:customer) { create(:atua_customer, tenant:, name: 'TERRAFEC MG', customer_group: manual_group) }

    it 'keeps the current group' do
      expect(described_class.call(tenant)).to eq(0)

      expect(customer.reload.customer_group).to eq(manual_group)
    end
  end

  context 'when it runs twice' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'USIMINAS S.A.') }

    it 'does not duplicate the groups' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to change(CustomerGroup, :count)
    end
  end

  context 'with customers and groups of another tenant' do
    let(:other_tenant) { create(:tenant) }
    let!(:stranger_group) { create(:customer_group, tenant: other_tenant, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
    let!(:customer) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }
    let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: 'ARCELORMITTAL TUBARAO') }

    it 'uses only the groups of the tenant' do
      described_class.call(tenant)

      expect(customer.reload.customer_group.tenant).to eq(tenant)
      expect(customer.customer_group.name).to eq('ARCELORMITTAL BRASIL S.A.')
      expect(stranger.reload.customer_group).to be_nil
    end
  end
end
