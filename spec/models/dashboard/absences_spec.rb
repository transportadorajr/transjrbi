require 'rails_helper'

RSpec.describe Dashboard::Absences do
  subject(:calendar) { described_class.new(tenant:, month: '2026-11') }

  let(:tenant) { create(:tenant) }
  let!(:ana) { create(:employee, tenant:, name: 'ANA', legal_id: '00000000041', admitted_on: Date.new(2025, 1, 5)) }
  let!(:bruno) { create(:employee, tenant:, name: 'BRUNO', legal_id: '00000000042') }

  before do
    create(:vacation, employee: ana, start_on: Date.new(2026, 10, 20), end_on: Date.new(2026, 11, 8))
    create(:vacation, employee: ana, start_on: Date.new(2026, 12, 20), end_on: Date.new(2026, 12, 29))
    create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 11, 10))
    create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 11, 11))
    create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 11, 20), leave_reason_type: 'medical_appointment')
    create(:work_schedule_day, employee: bruno, date: Date.new(2026, 11, 12))
  end

  it 'lists the vacations and the blocks of leave days that touch the month' do
    expect(calendar.absences.map { |absence| [absence.employee.name, absence.kind, absence.start_on, absence.end_on, absence.leave_reason_type] }).to eq(
      [
        ['ANA', :vacation, Date.new(2026, 10, 20), Date.new(2026, 11, 8), nil],
        ['BRUNO', :leave, Date.new(2026, 11, 10), Date.new(2026, 11, 11), 'medical_certificate'],
        ['BRUNO', :leave, Date.new(2026, 11, 20), Date.new(2026, 11, 20), 'medical_appointment'],
      ],
    )
    expect(calendar.absences.map { |absence| calendar.days_in_month(absence) }).to eq([8, 2, 1])
  end

  context 'when there are absences after the month' do
    before do
      create(:vacation, employee: bruno, acquisition_start_on: Date.new(2026, 1, 1), start_on: Date.new(2027, 2, 25), end_on: Date.new(2027, 3, 26))
      create(:vacation, employee: bruno, acquisition_start_on: Date.new(2026, 1, 1), start_on: Date.new(2027, 3, 1), end_on: Date.new(2027, 3, 30))
      create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 11, 30))
      create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 12, 1))
      create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2027, 1, 4))
    end

    it 'lists the absences that start in the next three months' do
      expect(calendar.upcoming_dates).to eq(Date.new(2026, 12, 1)..Date.new(2027, 2, 28))
      expect(calendar.upcoming_absences.map { |absence| [absence.employee.name, absence.kind, absence.start_on, absence.end_on, absence.days_count] }).to eq(
        [
          ['ANA', :vacation, Date.new(2026, 12, 20), Date.new(2026, 12, 29), 10],
          ['BRUNO', :leave, Date.new(2027, 1, 4), Date.new(2027, 1, 4), 1],
          ['BRUNO', :vacation, Date.new(2027, 2, 25), Date.new(2027, 3, 26), 30],
        ],
      )
    end
  end

  it 'counts the employees out in the month' do
    expect(calendar.employees_count).to eq(2)
    expect(calendar.employees_count(:vacation)).to eq(1)
    expect(calendar.employees_count(:leave)).to eq(1)
  end

  it 'lays the days out in weeks starting on Sunday' do
    weeks = calendar.weeks

    expect(weeks.first.map { |day| day&.date&.day }).to eq([1, 2, 3, 4, 5, 6, 7])
    expect(weeks.last.map { |day| day&.date&.day }).to eq([29, 30, nil, nil, nil, nil, nil])
    expect(calendar.days.find { |day| day.date == Date.new(2026, 11, 10) }.absences.map { |absence| absence.employee.name }).to eq(['BRUNO'])
  end

  it 'navigates between months and falls back to the current month' do
    expect([calendar.previous_month, calendar.next_month]).to eq([Date.new(2026, 10, 1), Date.new(2026, 12, 1)])

    travel_to Date.new(2026, 11, 24) do
      expect(described_class.new(tenant:, month: 'abc').month).to eq(Date.new(2026, 11, 1))
    end
  end
end
