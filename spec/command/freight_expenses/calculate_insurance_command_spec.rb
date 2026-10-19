require 'rails_helper'

RSpec.describe FreightExpenses::CalculateInsuranceCommand do
  let(:tenant) { create(:tenant) }

  context 'without insurance rates' do
    before { create(:atua_transport_document, tenant:, goods_value_cents: 838_998) }

    it 'does not record the insurance' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with an insurance rate' do
    let!(:october) { create(:insurance_rate, tenant:, valid_from: Date.new(2026, 10, 1)) }
    let!(:national) do
      create(:atua_transport_document, tenant:, number: '76001', goods_value_cents: 838_998, freight_cents: 55_504, destination_state: 'MG',
                                       issued_at: Time.zone.local(2026, 10, 5, 8))
    end
    let!(:international) do
      create(:atua_transport_document, tenant:, number: '76002', goods_value_cents: 838_998, freight_cents: 55_504, destination_state: 'ex',
                                       issued_at: Time.zone.local(2026, 10, 6, 8))
    end

    before do
      create(:atua_transport_document, tenant:, number: '76003', document_kind: 'ce', goods_value_cents: 100_000)
      create(:atua_transport_document, tenant:, number: '76004', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                       goods_value_cents: 100_000)
      create(:atua_transport_document, tenant:, number: '76005', canceled_at: Time.current, goods_value_cents: 100_000)
      create(:atua_transport_document, tenant: create(:tenant), number: '76006', goods_value_cents: 100_000)
    end

    it 'records the insurance of each transport document adding the IOF on the international ones' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))

      expect(FreightExpense.count).to eq(2)
      expect(FreightExpense.order(:transport_document_id).map { |expense| expense_values(expense) }).to eq(
        [
          ['76001', october, 894_502, BigDecimal('0.022'), BigDecimal('0'), 0, 197],
          ['76002', october, 894_502, BigDecimal('0.022'), BigDecimal('7.38'), 15, 212],
        ],
      )
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'insurance', commission_rule: nil, calculated_at: be_present))
    end

    it 'can run again without changing the insurance' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'keeps the other expenses of the same transport document' do
      commission = create(:freight_expense, tenant:, transport_document: national)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(national.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'insurance')
    end

    it 'uses the rate in force on the issue date of each transport document' do
      november = create(:insurance_rate, tenant:, valid_from: Date.new(2026, 10, 6), insurance_percentage: BigDecimal('0.03'))

      described_class.call(tenant)

      expect(FreightExpense.find_by!(transport_document: national)).to have_attributes(insurance_rate: october, amount_cents: 197)
      expect(FreightExpense.find_by!(transport_document: international)).to have_attributes(insurance_rate: november, iof_cents: 20,
                                                                                            amount_cents: 288)
    end

    it 'recalculates the insurance when the rate is corrected' do
      described_class.call(tenant)
      october.update!(insurance_percentage: BigDecimal('0.03'))

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))
      expect(FreightExpense.find_by!(transport_document: national)).to have_attributes(percentage: BigDecimal('0.03'), amount_cents: 268)
    end

    it 'removes the insurance of a transport document canceled afterwards' do
      described_class.call(tenant)
      international.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: international)).to be(false)
    end
  end

  def expense_values(expense)
    [expense.transport_document.number, expense.insurance_rate, expense.base_cents, expense.percentage, expense.iof_percentage,
     expense.iof_cents, expense.amount_cents]
  end
end
