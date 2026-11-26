require 'rails_helper'

RSpec.describe CustomerGroups::UnifyCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  context 'when the group exists inactive and the customers are spread over other groups' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU'], activated_at: nil) }
    let!(:steel) { create(:customer_group, tenant:, name: 'ACOMINAS', terms: ['ACOMINAS']) }
    let!(:own_group) { create(:customer_group, tenant:, name: 'GERDAU SUMMIT ACOS FUNDIDOS') }
    let!(:in_terms_group) { create(:atua_customer, tenant:, name: 'GERDAU ACOMINAS S.A.', customer_group: steel) }
    let!(:in_own_group) { create(:atua_customer, tenant:, name: 'Gerdau Summit Aços Fundidos', customer_group: own_group) }
    let!(:by_trade_name) { create(:atua_customer, tenant:, name: 'ACOS LONGOS S.A.', trade_name: 'GERDAU OURO BRANCO') }
    let!(:already_in) { create(:atua_customer, tenant:, name: 'GERDAU ACOS LONGOS', customer_group: gerdau) }
    let!(:other_customer) { create(:atua_customer, tenant:, name: 'ACOMINAS DISTRIBUIDORA', customer_group: steel) }
    let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: 'GERDAU DE OUTRA EMPRESA') }

    it 'moves every customer with the term in the name into the group and activates it' do
      expect { described_class.call(tenant, 'GERDAU', ['GERDAU']) }.not_to change(CustomerGroup, :count)

      expect(gerdau.reload).to be_activated
      expect(gerdau.customers).to contain_exactly(in_terms_group, in_own_group, by_trade_name, already_in)
      expect(other_customer.reload.customer_group).to eq(steel)
      expect(stranger.reload.customer_group).to be_nil
    end

    it 'recalculates the freight expenses of the tenant' do
      expect { described_class.call(tenant, 'GERDAU', ['GERDAU']) }
        .to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)
    end

    it 'does nothing when it runs again' do
      described_class.call(tenant, 'GERDAU', ['GERDAU'])

      expect { described_class.call(tenant, 'GERDAU', ['GERDAU']) }
        .to not_have_enqueued_job(FreightExpenses::CalculateJob).and(not_change { gerdau.reload.updated_at })
    end
  end

  context 'when the group has other terms' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['ACOS LONGOS']) }

    it 'adds the missing term and keeps the others' do
      described_class.call(tenant, 'GERDAU', ['GERDAU'])

      expect(gerdau.reload.terms).to eq(['ACOS LONGOS', 'GERDAU'])
    end
  end

  context 'when the group does not exist' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'GERDAU ACOMINAS S.A.') }

    it 'creates the active group with the terms' do
      group = nil

      expect { group = described_class.call(tenant, 'GERDAU', ['GERDAU']) }.to change(CustomerGroup, :count).by(1)

      expect(group).to have_attributes(name: 'GERDAU', terms: ['GERDAU'], tenant:)
      expect(group).to be_activated
      expect(customer.reload.customer_group).to eq(group)
    end
  end
end
