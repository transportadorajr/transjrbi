require 'rails_helper'

RSpec.describe CustomerGroups::RegroupCommand do
  let(:tenant) { create(:tenant) }
  let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM', 'TERRINHA ALIMENTOS']) }

  context 'when matching customers are in groups without terms' do
    let!(:own_group) { create(:customer_group, tenant:, name: '2JM COMERCIO LTDA') }
    let!(:shared_own_group) { create(:customer_group, tenant:, name: 'DISTRIBUIDORA BH LTDA') }
    let!(:moved) { create(:atua_customer, tenant:, name: '2JM COMERCIO LTDA', customer_group: own_group) }
    let!(:moved_by_trade_name) do
      create(:atua_customer, tenant:, name: 'DISTRIBUIDORA BH LTDA', trade_name: 'TERRINHA ALIMENTOS', customer_group: shared_own_group)
    end
    let!(:kept) { create(:atua_customer, tenant:, name: 'DISTRIBUIDORA BH LTDA', customer_group: shared_own_group) }
    let!(:ungrouped) { create(:atua_customer, tenant:, name: 'TERRINHA ALIMENTOS SP') }

    it 'moves them to the group and removes only the groups left empty' do
      expect { expect(described_class.call(food)).to eq(3) }.to change(CustomerGroup, :count).by(-1)

      expect(moved.reload.customer_group).to eq(food)
      expect(moved_by_trade_name.reload.customer_group).to eq(food)
      expect(ungrouped.reload.customer_group).to eq(food)
      expect(kept.reload.customer_group).to eq(shared_own_group)
      expect(CustomerGroup.exists?(own_group.id)).to be(false)
    end

    it 'does nothing when it runs again' do
      described_class.call(food)

      expect { expect(described_class.call(food)).to eq(0) }.not_to change(CustomerGroup, :count)
    end
  end

  context 'when a matching customer is in another group with terms' do
    let!(:other_group) { create(:customer_group, tenant:, name: 'DISTRIBUIDORES', terms: ['DISTRIBUIDORA']) }
    let!(:customer) { create(:atua_customer, tenant:, name: '2JM DISTRIBUIDORA', customer_group: other_group) }

    it 'keeps the customer where it is' do
      expect(described_class.call(food)).to eq(0)

      expect(customer.reload.customer_group).to eq(other_group)
    end
  end

  context 'when the group has no terms' do
    let!(:empty_terms_group) { create(:customer_group, tenant:, name: 'MANUAL') }
    let!(:customer) { create(:atua_customer, tenant:, name: 'MANUAL LTDA') }

    it 'moves nobody' do
      expect(described_class.call(empty_terms_group)).to eq(0)

      expect(customer.reload.customer_group).to be_nil
    end
  end

  context 'with a matching customer of another tenant' do
    let(:other_tenant) { create(:tenant) }
    let!(:stranger_group) { create(:customer_group, tenant: other_tenant, name: '2JM COMERCIO LTDA') }
    let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: '2JM COMERCIO LTDA', customer_group: stranger_group) }

    it 'does not touch it' do
      expect(described_class.call(food)).to eq(0)

      expect(stranger.reload.customer_group).to eq(stranger_group)
    end
  end
end
