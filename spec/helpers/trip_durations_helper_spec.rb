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
end
