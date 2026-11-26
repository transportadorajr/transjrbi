require 'rails_helper'

RSpec.describe FreightExpenses::CalculateAdvanceIcmsCommand do
  let(:tenant) { create(:tenant) }

  context 'without a customer group whose advance ICMS guides the carrier pays' do
    before do
      group = create(:customer_group, tenant:, name: 'USIMINAS')
      create(:atua_customer, tenant:, code: 602, customer_group: group)
      create(:atua_transport_document, tenant:, taker_code: 602, cfop: 6932, origin_state: 'SP', icms_cents: 9_000)
    end

    it 'does not provision the advance ICMS' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with a customer group whose advance ICMS guides the carrier pays' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', pays_advance_icms_at: Time.current) }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, customer_group: gerdau) }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 602, customer_group: usiminas) }
    let!(:first_pending) do
      create(:atua_transport_document, tenant:, number: '75845', taker_code: 601, cfop: 6932, origin_state: 'SP', icms_cents: 8_681)
    end
    let!(:second_pending) do
      create(:atua_transport_document, tenant:, number: '75846', taker_code: 601, cfop: 6932, origin_state: 'SP', icms_cents: 16_572)
    end
    let!(:paid) do
      create(:atua_transport_document, tenant:, number: '75830', taker_code: 601, cfop: 6932, origin_state: 'SP', icms_cents: 20_447)
    end
    let!(:other_tenant) { create(:tenant) }

    before do
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: paid, total_cents: 20_447)
      create(:atua_transport_document, tenant:, number: '75847', taker_code: 602, cfop: 6932, origin_state: 'SP', icms_cents: 9_000)
      create(:atua_transport_document, tenant:, number: '75848', taker_code: 601, cfop: 6932, origin_state: 'SP', icms_cents: 9_000,
                                       canceled_at: Time.current)
      create(:atua_transport_document, tenant:, number: '75849', taker_code: 601, cfop: 6353, origin_state: 'PR', icms_cents: 9_000)
      other_group = create(:customer_group, tenant: other_tenant, name: 'GERDAU', pays_advance_icms_at: Time.current)
      create(:atua_customer, tenant: other_tenant, code: 601, customer_group: other_group)
      create(:atua_transport_document, tenant: other_tenant, number: '75850', taker_code: 601, cfop: 6932, origin_state: 'SP', icms_cents: 9_000)
    end

    it 'provisions the ICMS of each CT-e of the group still without a guide' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))

      expect(FreightExpense.count).to eq(2)
      expect(FreightExpense.order(:transport_document_id).map { |expense| [expense.transport_document.number, expense.base_cents, expense.amount_cents] })
        .to eq([['75845', 8_681, 8_681], ['75846', 16_572, 16_572]])
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'advance_icms', calculated_at: be_present))
    end

    it 'can run again without changing the provisions' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'replaces the provision by the guide once the guide is linked to the CT-e' do
      described_class.call(tenant)
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: first_pending, total_cents: 8_681)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.advance_icms.map { |expense| expense.transport_document.number }).to eq(%w[75846])
    end

    it 'updates the provision when the ICMS of the CT-e changes' do
      described_class.call(tenant)
      second_pending.update!(icms_cents: 17_000)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(second_pending.freight_expenses.advance_icms.sole.amount_cents).to eq(17_000)
    end

    it 'keeps the other expenses of the same CT-e' do
      commission = create(:freight_expense, tenant:, transport_document: first_pending)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(first_pending.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'advance_icms')
    end

    it 'removes every provision when the group no longer has the guides paid by the carrier' do
      described_class.call(tenant)
      gerdau.update!(pays_advance_icms: false)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 2))
      expect(FreightExpense.count).to eq(0)
    end
  end
end
