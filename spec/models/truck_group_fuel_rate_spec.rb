require 'rails_helper'

RSpec.describe TruckGroupFuelRate do
  let(:truck_group) { create(:truck_group) }

  it 'allows one rate per month in the group' do
    rate = described_class.new(truck_group:, valid_month: Date.current.beginning_of_month, percentage: 10)

    expect(rate).not_to be_valid
    expect(rate.errors).to include(:valid_month)
  end

  it 'limits the percentage from 0 to 100' do
    rate = described_class.new(truck_group:, valid_month: Date.new(2020, 1, 1), percentage: 101)

    expect(rate).not_to be_valid
    expect(rate.errors).to include(:percentage)
  end

  describe '.for_month' do
    let(:august) { described_class.new(valid_month: Date.new(2026, 8, 1)) }
    let(:october) { described_class.new(valid_month: Date.new(2026, 10, 1)) }

    it 'picks the latest rate valid in the month and the first rate before every rate' do
      rates = [october, august]

      expect(described_class.for_month(rates, Date.new(2026, 7, 1))).to eq(august)
      expect(described_class.for_month(rates, Date.new(2026, 9, 1))).to eq(august)
      expect(described_class.for_month(rates, Date.new(2026, 11, 1))).to eq(october)
    end
  end
end
