require 'rails_helper'

RSpec.describe TripFilterForm do
  around { |example| travel_to(Date.new(2026, 10, 19)) { example.run } }

  context 'without filters' do
    it 'defaults to the current week from sunday to saturday grouped by driver' do
      form = described_class.new

      expect(form).to be_valid
      expect(form).to have_attributes(dimension: 'driver', period: Date.new(2026, 10, 18)..Date.new(2026, 10, 24))
      expect(form).not_to be_filtered
    end
  end

  context 'with filters' do
    it 'is filtered by the vehicle dimension' do
      expect(described_class.new(dimension: 'vehicle')).to be_filtered
    end

    it 'is filtered by another period' do
      expect(described_class.new(start_date: '2026-10-01', end_date: '2026-10-31')).to be_filtered
    end

    it 'is filtered by the plate' do
      expect(described_class.new(plate: 'AAA1A11')).to be_filtered
    end

    it 'is filtered by the product group' do
      expect(described_class.new(product_group_id: '7')).to be_filtered
    end
  end

  describe '.preset_period' do
    it 'returns the previous month' do
      expect(described_class.preset_period(:last_month)).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    end
  end

  describe 'validations' do
    it 'rejects an end date before the start date' do
      form = described_class.new(start_date: '2026-10-10', end_date: '2026-10-01')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Viagens até não pode ser anterior à data inicial'])
    end

    it 'rejects an unknown dimension' do
      expect(described_class.new(dimension: 'customer_group')).not_to be_valid
    end

    it 'rejects a truck group that is not a number' do
      expect(described_class.new(truck_group_id: 'abc')).not_to be_valid
    end

    it 'rejects a product group that is not a number' do
      expect(described_class.new(product_group_id: 'abc')).not_to be_valid
    end
  end
end
