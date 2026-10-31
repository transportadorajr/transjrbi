require 'rails_helper'

RSpec.describe GoodJob, '.configuration' do
  let(:cron) { described_class.configuration.cron }

  def next_runs(key, from:, count:)
    schedule = Fugit.parse_cron(cron.fetch(key).fetch(:cron))
    time = from

    Array.new(count) { time = schedule.next_time(time).to_t.in_time_zone }
  end

  def movement_runs(from:, to:)
    %i[atua_movements atua_movements_business_hours atua_movements_late_night]
      .flat_map { |key| next_runs(key, from:, count: 40).select { |time| time <= to } }
      .sort
      .map { |time| time.strftime('%d %H:%M') }
  end

  it 'schedules the jobs in the São Paulo time zone' do
    keys = %i[atua_movements atua_movements_business_hours atua_movements_late_night atua_previous_day atua_registries atua_month_closing]

    expect(cron.slice(*keys).transform_values { |entry| entry.slice(:class, :args) }).to eq(
      atua_movements: { class: 'Atua::ScheduleMovementsJob' },
      atua_movements_business_hours: { class: 'Atua::ScheduleMovementsJob' },
      atua_movements_late_night: { class: 'Atua::ScheduleMovementsJob' },
      atua_previous_day: { class: 'Atua::SchedulePreviousDayJob' },
      atua_registries: { class: 'Atua::ScheduleRegistriesJob' },
      atua_month_closing: { class: 'Atua::ScheduleMonthClosingJob' },
    )
  end

  it 'imports the movements every 30 minutes in business hours and hourly until 1h of the next day' do
    runs = movement_runs(from: Time.zone.local(2026, 10, 14, 1, 30), to: Time.zone.local(2026, 10, 15, 7))

    expect(runs).to eq(
      [
        '14 07:00', '14 08:00',
        *(8..17).flat_map { |hour| [format('14 %02d:30', hour), format('14 %02d:00', hour + 1)] },
        *(19..23).map { |hour| format('14 %02d:00', hour) },
        '15 00:00', '15 01:00', '15 07:00'
      ],
    )
  end

  it 'closes the saturday night at 1h and only returns on monday at 7h' do
    runs = movement_runs(from: Time.zone.local(2026, 10, 17, 22, 30), to: Time.zone.local(2026, 10, 19, 7))

    expect(runs).to eq(['17 23:00', '18 00:00', '18 01:00', '19 07:00'])
  end

  it 'imports the previous day every day at 0h30' do
    expect(next_runs(:atua_previous_day, from: Time.zone.local(2026, 10, 14, 6), count: 2))
      .to eq([Time.zone.local(2026, 10, 15, 0, 30), Time.zone.local(2026, 10, 16, 0, 30)])
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
