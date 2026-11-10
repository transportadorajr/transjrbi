require 'rails_helper'

RSpec.describe TripDuration do
  describe '.between' do
    it 'measures the time from the start to the end' do
      duration = described_class.between(Time.zone.local(2026, 10, 1, 8), Time.zone.local(2026, 10, 3, 10))

      expect(duration.seconds).to eq(50.hours.to_i)
      expect(duration.hours).to eq(50)
      expect(duration.days).to eq(2)
      expect(duration.remaining_hours).to eq(2)
    end

    it 'has no duration without the end or when the end is not after the start' do
      started_at = Time.zone.local(2026, 10, 1, 8)

      expect(described_class.between(started_at, nil)).to be_nil
      expect(described_class.between(nil, started_at)).to be_nil
      expect(described_class.between(started_at, started_at)).to be_nil
      expect(described_class.between(started_at, started_at - 1.hour)).to be_nil
    end
  end

  describe '.from_seconds' do
    it 'keeps only a positive amount of seconds' do
      expect(described_class.from_seconds(3600).hours).to eq(1)
      expect(described_class.from_seconds(0)).to be_nil
      expect(described_class.from_seconds(nil)).to be_nil
    end
  end

  describe '#hours' do
    it 'rounds to the nearest hour' do
      expect(described_class.new(89.minutes).hours).to eq(1)
      expect(described_class.new(90.minutes).hours).to eq(2)
    end
  end

  describe '#measured?' do
    it 'measures only the trips between one hour and fifteen days' do
      expect(described_class.new(59.minutes)).not_to be_measured
      expect(described_class.new(1.hour)).to be_measured
      expect(described_class.new(15.days)).to be_measured
      expect(described_class.new(15.days + 1.minute)).not_to be_measured
    end
  end

  describe '#net_per_hour' do
    it 'divides the net freight by the hours of the trip' do
      expect(described_class.new(38.hours).net_per_hour(Money.from_cents(500_000)).format).to eq('R$ 131,58')
    end
  end

  describe '#<=>' do
    it 'compares by the seconds' do
      expect(described_class.new(2.hours)).to be > described_class.new(1.hour)
    end
  end
end
