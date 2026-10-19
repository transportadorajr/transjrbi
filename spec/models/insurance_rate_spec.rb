require 'rails_helper'

RSpec.describe InsuranceRate do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the percentages' do
      rate = described_class.new(tenant:, insurance_percentage: 0, iof_percentage: -1)

      expect(rate).not_to be_valid
      expect(rate.errors.attribute_names).to contain_exactly(:insurance_percentage, :iof_percentage)
    end

    it 'accepts an IOF of zero' do
      expect(build(:insurance_rate, tenant:, iof_percentage: 0)).to be_valid
    end

    it 'accepts a single rate per tenant' do
      create(:insurance_rate, tenant:)

      expect(build(:insurance_rate, tenant:)).not_to be_valid
      expect(build(:insurance_rate, tenant: create(:tenant))).to be_valid
    end
  end

  describe 'calculation' do
    let(:rate) { build(:insurance_rate) }

    it 'calculates the insurance over the base rounding half up to cents' do
      expect(rate.insurance_cents(894_502)).to eq(197)
      expect(rate.insurance_cents(227_273)).to eq(50)
    end

    it 'calculates the IOF over the insurance' do
      expect(rate.iof_cents(197)).to eq(15)
      expect(rate.iof_cents(0)).to eq(0)
    end
  end
end
