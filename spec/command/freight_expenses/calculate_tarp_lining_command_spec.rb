require 'rails_helper'

RSpec.describe FreightExpenses::CalculateTarpLiningCommand do
  let(:tenant) { create(:tenant) }

  context 'without the Moinho Regio group' do
    before do
      customer = create(:atua_customer, tenant:, code: 601, name: 'MOINHO REGIO ALIMENTOS S/A')
      create(:atua_transport_document, tenant:, taker_code: customer.code)
    end

    it 'does not record the tarp lining' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with the Moinho Regio group' do
    let!(:group) { create(:customer_group, tenant:, name: 'MOINHO REGIO', terms: ['MOINHO REGIO'], activated_at: Time.current) }
    let!(:other_group) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS'], activated_at: Time.current) }
    let!(:moinho) { create(:atua_customer, tenant:, code: 601, name: 'MOINHO REGIO ALIMENTOS S/A', customer_group: group) }
    let!(:usiminas) { create(:atua_customer, tenant:, code: 602, name: 'USIMINAS CUBATAO', customer_group: other_group) }
    let!(:first_document) { create(:atua_transport_document, tenant:, number: '77001', taker_code: moinho.code) }
    let!(:second_document) { create(:atua_transport_document, tenant:, number: '77002', taker_code: moinho.code) }

    before do
      create(:atua_transport_document, tenant:, number: '77003', taker_code: usiminas.code)
      create(:atua_transport_document, tenant:, number: '77004', taker_code: moinho.code, document_kind: 'ce')
      create(:atua_transport_document, tenant:, number: '77005', taker_code: moinho.code,
                                       issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT)
      create(:atua_transport_document, tenant:, number: '77006', taker_code: moinho.code, canceled_at: Time.current)
    end

    it 'records R$ 55,00 for each transport document taken by the group' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))

      expect(FreightExpense.count).to eq(2)
      expect(FreightExpense.order(:transport_document_id).map { |expense| [expense.transport_document.number, expense.rate_cents, expense.amount_cents] })
        .to eq([['77001', 5_500, 5_500], ['77002', 5_500, 5_500]])
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'tarp_lining', calculated_at: be_present))
    end

    it 'can run again without changing the tarp lining' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'keeps the other expenses of the same transport document' do
      commission = create(:freight_expense, tenant:, transport_document: first_document)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(first_document.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'tarp_lining')
    end

    it 'removes the tarp lining of a transport document canceled afterwards' do
      described_class.call(tenant)
      second_document.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: second_document)).to be(false)
    end

    it 'removes every tarp lining when the group is deactivated' do
      described_class.call(tenant)
      group.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 2))
      expect(FreightExpense.count).to eq(0)
    end
  end
end
