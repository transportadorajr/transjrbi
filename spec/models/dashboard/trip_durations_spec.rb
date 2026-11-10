require 'rails_helper'

RSpec.describe Dashboard::TripDurations do
  context 'with closed trips, a trip in progress and trips out of the measured range' do
    subject(:durations) do
      described_class.new(
        [
          described_class.build_fact(26.hours.to_i, 300_000, false),
          described_class.build_fact(12.hours.to_i, 400_000, false),
          described_class.build_fact(nil, 900_000, true),
          described_class.build_fact(20.minutes.to_i, 900_000, false),
          described_class.build_fact(30.days.to_i, 900_000, false),
        ],
      )
    end

    it 'averages the closed trips weighting the net freight by the hours' do
      expect(durations.measured_count).to eq(2)
      expect(durations.average.hours).to eq(19)
      expect(durations.net_per_hour.format).to eq('R$ 184,21')
    end

    it 'counts the trips in progress and the closed trips left out of the average' do
      expect(durations.in_progress_count).to eq(1)
      expect(durations.excluded_count).to eq(2)
    end
  end

  context 'without measured trips' do
    subject(:durations) { described_class.new([]) }

    it 'has no average and no net per hour' do
      expect(durations.average).to be_nil
      expect(durations.net_per_hour).to be_nil
      expect(durations.measured_count).to eq(0)
    end
  end
end
