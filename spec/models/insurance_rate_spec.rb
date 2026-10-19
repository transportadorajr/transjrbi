require 'rails_helper'

RSpec.describe InsuranceRate do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the start of the validity and the percentages' do
      rate = described_class.new(tenant:, insurance_percentage: 0, iof_percentage: -1)

      expect(rate).not_to be_valid
      expect(rate.errors.attribute_names).to contain_exactly(:valid_from, :insurance_percentage, :iof_percentage)
    end

    it 'accepts an IOF of zero' do
      expect(build(:insurance_rate, tenant:, iof_percentage: 0)).to be_valid
    end

    it 'rejects two rates starting on the same day in the tenant' do
      create(:insurance_rate, tenant:)

      expect(build(:insurance_rate, tenant:)).not_to be_valid
      expect(build(:insurance_rate, tenant: create(:tenant))).to be_valid
    end
  end

  describe '.for_date' do
    let(:october) { build(:insurance_rate, valid_from: Date.new(2026, 10, 1)) }
    let(:november) { build(:insurance_rate, valid_from: Date.new(2026, 11, 15)) }

    it 'uses the rate in force on the date' do
      expect(described_class.for_date([october, november], Date.new(2026, 11, 14))).to eq(october)
      expect(described_class.for_date([october, november], Date.new(2026, 11, 15))).to eq(november)
    end

    it 'falls back to the oldest rate before the first validity' do
      expect(described_class.for_date([november, october], Date.new(2026, 9, 1))).to eq(october)
    end

    it 'returns nothing without rates' do
      expect(described_class.for_date([], Date.new(2026, 10, 1))).to be_nil
    end
  end

  describe '.current' do
    let!(:past) { create(:insurance_rate, tenant:, valid_from: Date.current.prev_month) }

    before { create(:insurance_rate, tenant:, valid_from: Date.current.next_month) }

    it 'returns the rate in force today' do
      expect(described_class.current(tenant)).to eq(past)
    end
  end

  describe 'scopes' do
    let!(:october) { create(:insurance_rate, tenant:, valid_from: Date.new(2026, 10, 1)) }
    let!(:november) { create(:insurance_rate, tenant:, valid_from: Date.new(2026, 11, 1)) }

    it 'filters by the start of the validity' do
      expect(described_class.by_valid_from_start('2026-10-15')).to contain_exactly(november)
      expect(described_class.by_valid_from_end('2026-10-15')).to contain_exactly(october)
      expect(described_class.by_valid_from_start('invalid')).to contain_exactly(october, november)
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
