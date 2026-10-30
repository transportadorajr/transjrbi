require 'rails_helper'

RSpec.describe InsuranceRates::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'with transport documents' do
    let!(:document) do
      create(:atua_transport_document, tenant:, goods_value_cents: 838_998, freight_cents: 55_504, issued_at: Time.zone.local(2026, 9, 3, 8))
    end

    before do
      manifest = create(:atua_manifest, tenant:)
      create(:atua_transport_document_manifest, tenant:, transport_document_code: document.code, manifest_number: manifest.number,
                                                branch_name: manifest.branch_name)
    end

    it 'creates the default rate and calculates the insurance' do
      expect { described_class.call(tenant) }.to change(InsuranceRate, :count).by(1)

      expect(InsuranceRate.find_by!(tenant:)).to have_attributes(insurance_percentage: BigDecimal('0.022'), iof_percentage: BigDecimal('7.38'))
      expect(FreightExpense.insurance.find_by!(transport_document: document).amount_cents).to eq(197)
    end

    it 'can run again without duplicating the rate' do
      rate = described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(rate) }.not_to change(InsuranceRate, :count)
    end
  end
end
