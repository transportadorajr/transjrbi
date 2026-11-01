require 'rails_helper'

RSpec.describe TripExpenses do
  let(:tenant) { create(:tenant) }
  let!(:first_document) do
    create(:atua_transport_document, tenant:, number: '100', branch_code: 2, freight_cents: 300_000, weight_freight_cents: 260_000, toll_cents: 15_000, icms_cents: 25_000)
  end
  let!(:second_document) { create(:atua_transport_document, tenant:, number: '200', toll_cents: 0) }
  let!(:canceled_document) { create(:atua_transport_document, tenant:, number: '300', canceled_at: Time.current) }
  let!(:outside_document) { create(:atua_transport_document, tenant:, number: '400') }
  let!(:commission) { create(:freight_expense, tenant:, transport_document: second_document, amount_cents: 10_000) }
  let!(:unload) { create(:atua_expense, tenant:, cost_object: first_document, total_cents: 35_000) }
  let(:documents) { Atua::TransportDocument.where(id: [first_document, second_document, canceled_document]) }

  before do
    create(:atua_toll_voucher, tenant:, transport_document_number: '100', branch_code: 2, toll_cents: 15_000)
    create(:freight_expense, tenant:, transport_document: canceled_document, amount_cents: 99_999)
    create(:freight_expense, tenant:, transport_document: outside_document, amount_cents: 99_999)
    create(:atua_expense, tenant:, cost_object: first_document, total_cents: 99_999, removed_from_atua_at: Time.current)
    create(:atua_expense, tenant:, cost_object: canceled_document, total_cents: 99_999)
  end

  it 'unifies the internal expenses, the discounted toll and the Atua expenses by transport document' do
    trip_expenses = described_class.for(documents, internal: true, atua: true)

    expect(trip_expenses.items.map { |item| [item.transport_document.number, item.kind, item.amount.cents] }).to eq(
      [['100', :toll, 15_000], ['100', :expense, 35_000], ['200', :freight_expense, 10_000]],
    )
    expect(trip_expenses.total).to eq(Money.from_cents(60_000))
  end

  it 'totals the same deductions as the net freight' do
    trip_expenses = described_class.for(documents, internal: true, atua: true)
    net_freight = NetFreight.for(documents)

    expect(trip_expenses.total).to eq(net_freight.freight - net_freight.net)
  end

  it 'leaves out the internal expenses and the toll when they are not requested' do
    trip_expenses = described_class.for(documents, internal: false, atua: true)

    expect(trip_expenses.items.map(&:record)).to eq([unload])
    expect(trip_expenses.total).to eq(Money.from_cents(35_000))
  end

  it 'leaves out the Atua expenses when they are not requested' do
    trip_expenses = described_class.for(documents, internal: true, atua: false)

    expect(trip_expenses.items.map(&:kind)).to eq(%i[toll freight_expense])
    expect(trip_expenses.total).to eq(Money.from_cents(25_000))
  end
end
