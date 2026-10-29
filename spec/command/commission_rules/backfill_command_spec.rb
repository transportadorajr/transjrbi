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
      expect(group.commission_rules.order(:id).pluck(:name, :destination_type, :base_type, :percentage, :cities, :recipient_terms)).to eq(
        [
          ['Nacional', 'national', 'freight_without_icms', BigDecimal('2.0'), [], []],
          ['Argentina', 'foreign', 'freight', BigDecimal('1.3'), ['Buenos Aires', 'Puerto Iguazú', 'Rosario'],
           %w[FERROSIDER ACINDAR SIAT TERNIUM]],
          ['Paraguai', 'foreign', 'freight', BigDecimal('1.5'), ['Asunción', 'Ciudad del Este'],
           %w[LACERIE GALLO ACEROS FERROPAR CJX ELIN FATA WADRA MERCOFER MONICA PERFILADOS]],
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

  context 'when the foreign rules were registered without recipient terms' do
    let!(:group) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS', customer_group: group) }
    let!(:recipient) { create(:atua_customer, tenant:, code: 601, name: 'L ACERIE S A', city: 'EXTERIOR', state: 'EX') }
    let!(:national) { create(:commission_rule, tenant:, customer_group: group) }
    let!(:argentina) { create(:commission_rule, :argentina, tenant:, customer_group: group, recipient_terms: []) }
    let!(:paraguay) { create(:commission_rule, :paraguay, tenant:, customer_group: group, recipient_terms: ['GALLO'], percentage: BigDecimal('1.6')) }
    let!(:to_exterior) do
      create(:atua_transport_document, tenant:, taker_code: 501, recipient_code: 601, recipient_name: 'L ACERIE S A',
                                       destination_city: 'EXTERIOR', destination_state: 'EX', freight_cents: 1_000_000)
    end
    let!(:to_argentina) do
      create(:atua_transport_document, tenant:, taker_code: 501, recipient_name: 'ACINDAR SA', destination_city: 'EXTERIOR',
                                       destination_state: 'EX', freight_cents: 2_000_000)
    end

    it 'fills only the empty recipient terms and calculates the commissions of the foreign CT-es' do
      expect { described_class.call(tenant) }.not_to change(CommissionRule, :count)

      expect(argentina.reload.recipient_terms).to eq(%w[FERROSIDER ACINDAR SIAT TERNIUM])
      expect(paraguay.reload).to have_attributes(recipient_terms: ['GALLO'], percentage: BigDecimal('1.6'))
      expect(national.reload.recipient_terms).to eq([])
      expect(FreightExpense.find_by!(transport_document: to_argentina)).to have_attributes(commission_rule: argentina, amount_cents: 26_000)
      expect(FreightExpense.exists?(transport_document: to_exterior)).to be(false)
    end

    it 'can run again without changing the terms' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to(change { CommissionRule.order(:id).pluck(:recipient_terms, :updated_at) })
    end
  end
end
