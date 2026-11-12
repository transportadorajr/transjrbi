require 'rails_helper'

RSpec.describe Types::ZonedDateTimeType do
  subject(:type) { described_class.new }

  around do |example|
    original_tz = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'UTC'
    example.run
  ensure
    ENV['TZ'] = original_tz
  end

  describe '#cast' do
    it 'reads a datetime-local value in the app time zone when the server runs in UTC' do
      expect(type.cast('2026-11-11T17:30')).to eq(Time.zone.local(2026, 11, 11, 17, 30))
    end

    it 'keeps the offset written in the value' do
      expect(type.cast('2026-11-11T17:30:00Z')).to eq(Time.utc(2026, 11, 11, 17, 30))
    end

    it 'keeps a time that is already a time' do
      time = Time.zone.local(2026, 11, 11, 8)

      expect(type.cast(time)).to eq(time)
    end

    it 'returns nil for a blank or invalid value' do
      expect(type.cast('')).to be_nil
      expect(type.cast('2026-13-45T99:99')).to be_nil
    end
  end
end
