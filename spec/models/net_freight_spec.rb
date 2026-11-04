require 'rails_helper'

RSpec.describe NetFreight do
  let(:tenant) { create(:tenant) }
  let!(:document) do
    create(:atua_transport_document, tenant:, branch_code: 2, freight_cents: 1_000_000, weight_freight_cents: 850_000, toll_cents: 30_000,
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
  let!(:insurance) do
    create(:freight_expense, :insurance, tenant:, insurance_rate:, transport_document: document, amount_cents: 9_734,
                                         international_percentage: BigDecimal('0.065'), international_insurance_cents: 6_860, iof_cents: 552)
  end
  let!(:tarp_lining) { create(:freight_expense, :tarp_lining, tenant:, transport_document: document) }
  let!(:fuel) { create(:freight_expense, :fuel, tenant:, transport_document: document, amount_cents: 300_000) }
  let!(:canceled_fuel) { create(:freight_expense, :fuel, tenant:, transport_document: canceled, amount_cents: 150_000) }
  let!(:canceled_insurance) do
    create(:freight_expense, :insurance, tenant:, insurance_rate:, transport_document: canceled, amount_cents: 1_000)
  end
  let!(:unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 45_000)
  end
  let!(:removed_unload) do
    create(:atua_expense, tenant:, cost_object: document, total_cents: 10_000, removed_from_atua_at: Time.current)
  end

  let!(:toll_voucher) { create(:atua_toll_voucher, tenant:, transport_document_number: document.number, branch_code: 2, toll_cents: 58_500) }
  let!(:canceled_toll_voucher) do
    create(:atua_toll_voucher, tenant:, transport_document_number: document.number, branch_code: 2, toll_cents: 7_000, canceled_on: Date.new(2026, 10, 2))
  end

  it 'subtracts the commissions, the tonnage costs, the national and international cargo insurance, the tarp lining, the fuel, the Atua expenses and the discounted toll from the valid transport documents' do
    net_freight = described_class.for(tenant.atua_transport_documents)

    expect(net_freight.freight).to eq(Money.from_cents(1_200_000))
    expect(net_freight.commission).to eq(Money.from_cents(18_000))
    expect(net_freight.tonnage).to eq(Money.from_cents(40_853))
    expect(net_freight.insurance).to eq(Money.from_cents(2_322))
    expect(net_freight.international_insurance).to eq(Money.from_cents(7_412))
    expect(net_freight.tarp_lining).to eq(Money.from_cents(5_500))
    expect(net_freight.fuel).to eq(Money.from_cents(300_000))
    expect(net_freight.expenses).to eq(Money.from_cents(45_000))
    expect(net_freight.toll).to eq(Money.from_cents(58_500))
    expect(net_freight.net).to eq(Money.from_cents(722_413))
  end

  context 'with value complements of the transport documents' do
    let!(:complement) do
      create(:atua_transport_document, tenant:, issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, freight_cents: 45_000,
                                       complemented_transport_document: document)
    end

    it 'credits the complements to the original and does not change its gross freight' do
      net_freight = described_class.for(tenant.atua_transport_documents.where(id: document.id))

      expect(net_freight.freight).to eq(Money.from_cents(1_000_000))
      expect(net_freight.complement_credit).to eq(Money.from_cents(45_000))
      expect(net_freight.complement_transfer).to eq(Money.from_cents(0))
      expect(net_freight.net).to eq(Money.from_cents(567_413))
    end

    it 'transfers the value of the complement, leaving it without net freight' do
      net_freight = described_class.for(tenant.atua_transport_documents.where(id: complement.id))

      expect(net_freight.freight).to eq(Money.from_cents(45_000))
      expect(net_freight.complement_transfer).to eq(Money.from_cents(45_000))
      expect(net_freight.net).to eq(Money.from_cents(0))
    end

    it 'counts the complement once when both documents are listed' do
      net_freight = described_class.for(tenant.atua_transport_documents.where(id: [document.id, complement.id]))

      expect(net_freight.freight).to eq(Money.from_cents(1_045_000))
      expect(net_freight.net).to eq(Money.from_cents(567_413))
    end
  end
end
