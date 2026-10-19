require 'rails_helper'

RSpec.describe InsuranceRates::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'with transport documents' do
    let!(:document) do
      create(:atua_transport_document, tenant:, goods_value_cents: 838_998, freight_cents: 55_504, issued_at: Time.zone.local(2026, 9, 3, 8))
    end

    before { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 3, 8)) }

    it 'creates the default rate from the oldest transport document and calculates the insurance' do
      expect { described_class.call(tenant) }.to change(InsuranceRate, :count).by(1)

      expect(tenant.insurance_rates.sole).to have_attributes(valid_from: Date.new(2026, 9, 3), insurance_percentage: BigDecimal('0.022'),
                                                             iof_percentage: BigDecimal('7.38'))
      expect(FreightExpense.insurance.find_by!(transport_document: document).amount_cents).to eq(197)
    end

    it 'can run again without duplicating the rate' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change(InsuranceRate, :count)
    end
  end

  context 'without transport documents' do
    it 'creates the default rate starting today' do
      described_class.call(tenant)

      expect(tenant.insurance_rates.sole.valid_from).to eq(Date.current)
    end
  end
end
