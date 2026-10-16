require 'rails_helper'

RSpec.describe FreightExpenses::CalculateCommissionsCommand do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
  let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS CUBATAO', customer_group: usiminas) }
  let!(:national) { create(:commission_rule, tenant:, customer_group: usiminas) }
  let!(:argentina) { create(:commission_rule, :argentina, tenant:, customer_group: usiminas) }
  let!(:paraguay) { create(:commission_rule, :paraguay, tenant:, customer_group: usiminas) }

  context 'with transport documents of the Usiminas group' do
    let!(:to_minas) do
      create(:atua_transport_document, tenant:, number: '74001', taker_code: 501, destination_city: 'IPATINGA', destination_state: 'MG',
                                       freight_cents: 1_000_000, icms_cents: 120_000)
    end
    let!(:to_rosario) do
      create(:atua_transport_document, tenant:, number: '74002', taker_code: 501, destination_city: 'ROSARIO', destination_state: 'EX',
                                       freight_cents: 2_000_000, icms_cents: 0)
    end
    let!(:to_asuncion) do
      create(:atua_transport_document, tenant:, number: '74003', taker_code: 501, destination_city: 'ASUNCION', destination_state: 'EX',
                                       freight_cents: 3_000_000, icms_cents: 50_000)
    end
    let!(:to_santiago) do
      create(:atua_transport_document, tenant:, number: '74004', taker_code: 501, destination_city: 'SANTIAGO', destination_state: 'EX',
                                       freight_cents: 4_000_000)
    end
    let!(:ce) do
      create(:atua_transport_document, tenant:, number: '74005', taker_code: 501, document_kind: 'ce', destination_state: 'MG')
    end
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '74006', taker_code: 501, issue_kind: 'Complemento de Valores',
                                       destination_state: 'MG')
    end

    it 'records the commission of each normal CT-e with the rule of its destination' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 3, removed: 0))

      expect(FreightExpense.count).to eq(3)
      expect(FreightExpense.order(:transport_document_id).map { |expense| expense_values(expense) }).to eq(
        [
          ['74001', national, 880_000, 120_000, BigDecimal('2.0'), 17_600],
          ['74002', argentina, 2_000_000, 0, BigDecimal('1.3'), 26_000],
          ['74003', paraguay, 3_000_000, 0, BigDecimal('1.5'), 45_000],
        ],
      )
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'commission', calculated_at: be_present))
    end

    it 'can run again without changing the commissions' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'recalculates every commission when the percentage of a rule changes' do
      described_class.call(tenant)
      national.update!(percentage: BigDecimal('2.5'))

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(FreightExpense.find_by!(transport_document: to_minas)).to have_attributes(percentage: BigDecimal('2.5'), amount_cents: 22_000)
    end

    it 'calculates the commission of a foreign city once it is added to a rule' do
      described_class.call(tenant)
      argentina.update!(cities: argentina.cities + ['Santiago'])

      described_class.call(tenant)

      expect(FreightExpense.find_by!(transport_document: to_santiago)).to have_attributes(commission_rule: argentina, amount_cents: 52_000)
    end

    it 'removes the commission of a transport document canceled after the calculation' do
      described_class.call(tenant)
      to_rosario.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: to_rosario)).to be(false)
    end

    it 'removes the commissions when the rules are deactivated' do
      described_class.call(tenant)
      [national, argentina, paraguay].each { |rule| rule.update!(activated_at: nil) }

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 3))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with a transport document whose taker is not in the group' do
    let!(:sender_only) do
      create(:atua_transport_document, tenant:, sender_code: 501, taker_code: 999, destination_state: 'MG', freight_cents: 1_000_000)
    end

    it 'does not pay commission' do
      described_class.call(tenant)

      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with a commission rule of another tenant' do
    let(:other_tenant) { create(:tenant) }
    let(:stranger_group) { create(:customer_group, tenant: other_tenant, name: 'USIMINAS') }
    let!(:stranger_customer) { create(:atua_customer, tenant: other_tenant, code: 501, customer_group: stranger_group) }
    let!(:stranger_rule) { create(:commission_rule, tenant: other_tenant, customer_group: stranger_group) }
    let!(:stranger_document) { create(:atua_transport_document, tenant: other_tenant, taker_code: 501, destination_state: 'MG') }

    it 'calculates only the commissions of the given tenant' do
      described_class.call(tenant)

      expect(FreightExpense.count).to eq(0)
    end
  end

  def expense_values(expense)
    [expense.transport_document.number, expense.commission_rule, expense.base_cents, expense.icms_cents, expense.percentage,
     expense.amount_cents]
  end
end
