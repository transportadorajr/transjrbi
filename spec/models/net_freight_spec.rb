require 'rails_helper'

RSpec.describe NetFreight do
  let(:tenant) { create(:tenant) }
  let!(:document) { create(:atua_transport_document, tenant:, freight_cents: 1_000_000) }
  let!(:canceled) { create(:atua_transport_document, tenant:, freight_cents: 500_000, canceled_at: Time.current) }
  let!(:commission) { create(:freight_expense, tenant:, transport_document: document, amount_cents: 18_000) }
  let!(:tonnage) { create(:freight_expense, :tonnage, tenant:, transport_document: document, amount_cents: 40_853) }
  let!(:unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 45_000)
  end
  let!(:removed_unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 10_000, removed_from_atua_at: Time.current)
  end

  it 'subtracts the commissions, the tonnage costs and the Atua expenses from the freight of the valid transport documents' do
    net_freight = described_class.for(tenant.atua_transport_documents)

    expect(net_freight.freight).to eq(Money.from_cents(1_000_000))
    expect(net_freight.commission).to eq(Money.from_cents(18_000))
    expect(net_freight.tonnage).to eq(Money.from_cents(40_853))
    expect(net_freight.expenses).to eq(Money.from_cents(45_000))
    expect(net_freight.net).to eq(Money.from_cents(896_147))
  end
end
