require 'rails_helper'

RSpec.describe CustomerGroupAssignmentForm do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU']) }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:inactive_group) { create(:customer_group, tenant:, name: 'MOVISTAR', activated_at: nil) }
  let!(:stranger_group) { create(:customer_group, tenant: other_tenant, name: 'GRUPO DE OUTRA EMPRESA') }
  let!(:customer) { create(:atua_customer, tenant:, name: 'GERDAU ACOMINAS S.A.') }

  describe '.for_customer' do
    it 'fills the current group of the customer' do
      customer.update!(customer_group: usiminas)

      expect(described_class.for_customer(customer).customer_group_id).to eq(usiminas.id)
    end
  end

  describe '#customer_groups' do
    it 'offers only the active groups of the tenant ordered by name' do
      expect(described_class.for_customer(customer).customer_groups).to eq([gerdau, usiminas])
    end
  end

  describe '#save' do
    it 'moves the customer into the chosen group' do
      form = described_class.new(customer:, customer_group_id: gerdau.id)

      expect(form.save).to be(true)
      expect(customer.reload.customer_group).to eq(gerdau)
    end

    it 'requires a group' do
      form = described_class.new(customer:, customer_group_id: nil)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Grupo não pode ficar em branco'])
    end

    it 'rejects an inactive group' do
      form = described_class.new(customer:, customer_group_id: inactive_group.id)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Grupo não é válido'])
      expect(customer.reload.customer_group).to be_nil
    end

    it 'rejects a group of another tenant' do
      form = described_class.new(customer:, customer_group_id: stranger_group.id)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Grupo não é válido'])
      expect(customer.reload.customer_group).to be_nil
    end
  end
end
