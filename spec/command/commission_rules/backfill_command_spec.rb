require 'rails_helper'

RSpec.describe CommissionRules::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'without the Usiminas group' do
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USINAS SIDERURGICAS DE MINAS GERAIS S/A USIMINAS') }
    let!(:document) do
      create(:atua_transport_document, tenant:, taker_code: 501, destination_state: 'MG', freight_cents: 1_000_000, icms_cents: 120_000)
    end

    it 'creates the group, its three rules and calculates the commissions' do
      expect { described_class.call(tenant) }.to change(CommissionRule, :count).by(3).and change(CustomerGroup, :count).by(1)

      group = tenant.customer_groups.find_by!(name: 'USIMINAS')
      expect(group.terms).to eq(['USIMINAS'])
      expect(usiminas_customer.reload.customer_group).to eq(group)
      expect(group.commission_rules.order(:id).pluck(:name, :destination_type, :base_type, :percentage, :cities)).to eq(
        [
          ['Nacional', 'national', 'freight_without_icms', BigDecimal('2.0'), []],
          ['Argentina', 'foreign', 'freight', BigDecimal('1.3'), ['Buenos Aires', 'Puerto Iguazú', 'Rosario']],
          ['Paraguai', 'foreign', 'freight', BigDecimal('1.5'), ['Asunción', 'Ciudad del Este']],
        ],
      )
      expect(group.commission_rules).to all(be_activated)
      expect(FreightExpense.sole).to have_attributes(transport_document: document, amount_cents: 17_600)
    end

    it 'can run again without duplicating the rules' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change(CommissionRule, :count)
    end
  end

  context 'with a group whose terms already match Usiminas' do
    let!(:group) { create(:customer_group, tenant:, name: 'GRUPO USIMINAS', terms: ['USIMINAS']) }

    it 'adds the rules to the existing group' do
      expect { described_class.call(tenant) }.not_to change(CustomerGroup, :count)

      expect(group.commission_rules.count).to eq(3)
    end
  end

  context 'when the group already has commission rules' do
    let!(:group) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:rule) { create(:commission_rule, tenant:, customer_group: group, percentage: BigDecimal('3.0')) }

    it 'keeps the rules registered by the users' do
      expect { described_class.call(tenant) }.not_to change(CommissionRule, :count)

      expect(rule.reload.percentage).to eq(BigDecimal('3.0'))
    end
  end
end
