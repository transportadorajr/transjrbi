require 'rails_helper'

RSpec.describe TripDurationsHelper do
  describe '#trip_duration' do
    it 'shows the days and the hours of the trip' do
      expect(helper.trip_duration(TripDuration.new(24.hours))).to eq('1 dia')
      expect(helper.trip_duration(TripDuration.new(50.hours))).to eq('2 dias e 2 horas')
      expect(helper.trip_duration(TripDuration.new(25.hours))).to eq('1 dia e 1 hora')
      expect(helper.trip_duration(TripDuration.new(18.hours))).to eq('18 horas')
    end

    it 'shows a trip shorter than one hour' do
      expect(helper.trip_duration(TripDuration.new(20.minutes))).to eq('Menos de 1 hora')
    end

    it 'shows a dash without a duration' do
      expect(helper.trip_duration(nil)).to eq('-')
    end
  end

  describe '#trip_duration_in_progress' do
    it 'shows the partial time apart from the final duration' do
      expect(helper.trip_duration_in_progress(TripDuration.new(29.hours))).to have_css('.trip-duration-in-progress', text: 'Em andamento há 1 dia e 5 horas')
    end
  end

  describe '#trip_durations_none_closed_note' do
    def durations(*facts)
      Dashboard::TripDurations.new(facts)
    end

    it 'explains the blank average when every trip of the period is still in progress' do
      note = helper.trip_durations_none_closed_note(durations(Dashboard::TripDurations.build_fact(nil, 100_000, true)))

      expect(note).to include('Nenhuma viagem do período foi encerrada ainda.')
    end

    it 'stays hidden when a trip was closed or there are no trips' do
      closed = durations(Dashboard::TripDurations.build_fact(26.hours.to_i, 100_000, false), Dashboard::TripDurations.build_fact(nil, 100_000, true))

      expect(helper.trip_durations_none_closed_note(closed)).to be_nil
      expect(helper.trip_durations_none_closed_note(durations)).to be_nil
    end
  end
end
