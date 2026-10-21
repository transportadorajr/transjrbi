require 'rails_helper'

RSpec.describe NetFreight do
  let(:tenant) { create(:tenant) }
  let!(:document) do
    create(:atua_transport_document, tenant:, freight_cents: 1_000_000, weight_freight_cents: 850_000, toll_cents: 30_000,
                                     icms_cents: 120_000)
  end
  let!(:voucher_document) do
    create(:atua_transport_document, tenant:, freight_cents: 200_000, weight_freight_cents: 200_000, toll_cents: 15_000, icms_cents: 0)
  end
  let!(:canceled) do
    create(:atua_transport_document, tenant:, freight_cents: 500_000, weight_freight_cents: 480_000, toll_cents: 20_000,
                                     canceled_at: Time.current)
  end
  let!(:commission) { create(:freight_expense, tenant:, transport_document: document, amount_cents: 18_000) }
  let!(:tonnage) { create(:freight_expense, :tonnage, tenant:, transport_document: document, amount_cents: 40_853) }
  let!(:insurance_rate) { create(:insurance_rate, tenant:) }
  let!(:insurance) { create(:freight_expense, :insurance, tenant:, insurance_rate:, transport_document: document, amount_cents: 2_322) }
  let!(:tarp_lining) { create(:freight_expense, :tarp_lining, tenant:, transport_document: document) }
  let!(:canceled_insurance) do
    create(:freight_expense, :insurance, tenant:, insurance_rate:, transport_document: canceled, amount_cents: 1_000)
  end
  let!(:unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 45_000)
  end
  let!(:removed_unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 10_000, removed_from_atua_at: Time.current)
  end

  it 'subtracts the commissions, the tonnage costs, the cargo insurance, the tarp lining, the Atua expenses and the toll inside the freight from the valid transport documents' do
    net_freight = described_class.for(tenant.atua_transport_documents)

    expect(net_freight.freight).to eq(Money.from_cents(1_200_000))
    expect(net_freight.commission).to eq(Money.from_cents(18_000))
    expect(net_freight.tonnage).to eq(Money.from_cents(40_853))
    expect(net_freight.insurance).to eq(Money.from_cents(2_322))
    expect(net_freight.tarp_lining).to eq(Money.from_cents(5_500))
    expect(net_freight.expenses).to eq(Money.from_cents(45_000))
    expect(net_freight.toll).to eq(Money.from_cents(30_000))
    expect(net_freight.toll_outside_freight).to eq(Money.from_cents(15_000))
    expect(net_freight.net).to eq(Money.from_cents(1_058_325))
  end
end
