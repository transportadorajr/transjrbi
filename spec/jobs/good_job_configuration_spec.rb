require 'rails_helper'

RSpec.describe GoodJob, '.configuration' do
  let(:cron) { described_class.configuration.cron }

  def next_runs(key, from:, count:)
    schedule = Fugit.parse_cron(cron.fetch(key).fetch(:cron))
    time = from

    Array.new(count) { time = schedule.next_time(time).to_t.in_time_zone }
  end

  it 'schedules the jobs in the São Paulo time zone' do
    expect(cron.slice(:atua_movements, :atua_registries, :atua_month_closing).transform_values { |entry| entry.slice(:class, :args) }).to eq(
      atua_movements: { class: 'Atua::ScheduleMovementsJob', args: [10] },
      atua_registries: { class: 'Atua::ScheduleRegistriesJob' },
      atua_month_closing: { class: 'Atua::ScheduleMonthClosingJob' },
    )
  end

  it 'imports the movements every hour from 6h to 2h of the next day' do
    runs = next_runs(:atua_movements, from: Time.zone.local(2026, 10, 14, 3), count: 22)

    expect(runs.map { |time| time.strftime('%d %H:%M') }).to eq(
      [*(6..23).map { |hour| format('14 %02d:00', hour) }, *(0..2).map { |hour| format('15 %02d:00', hour) }, '15 06:00'],
    )
  end

  it 'imports the registries every day at 5h30' do
    expect(next_runs(:atua_registries, from: Time.zone.local(2026, 10, 14, 6), count: 2))
      .to eq([Time.zone.local(2026, 10, 15, 5, 30), Time.zone.local(2026, 10, 16, 5, 30)])
  end

  it 'closes the previous month on the third day at 4h' do
    expect(next_runs(:atua_month_closing, from: Time.zone.local(2026, 10, 14), count: 2))
      .to eq([Time.zone.local(2026, 11, 3, 4), Time.zone.local(2026, 12, 3, 4)])
  end
end
