require 'rails_helper'

RSpec.describe Dashboard::WorkSchedule do
  subject(:schedule) { described_class.new(tenant:, week: '2026-11-25') }

  let(:tenant) { create(:tenant) }

  describe 'week' do
    it 'starts the week on the Sunday of the given date' do
      expect(schedule.week_start).to eq(Date.new(2026, 11, 22))
      expect(schedule.dates).to eq(Date.new(2026, 11, 22)..Date.new(2026, 11, 28))
      expect(schedule.previous_week).to eq(Date.new(2026, 11, 15))
      expect(schedule.next_week).to eq(Date.new(2026, 11, 29))
    end

    it 'falls back to the current week on an invalid date' do
      travel_to Date.new(2026, 11, 26) do
        expect(described_class.new(tenant:, week: 'abc').week_start).to eq(Date.new(2026, 11, 22))
      end
    end
  end

  describe '#rows' do
    let!(:driver) { create(:driver, tenant:, code: 501) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', driver:) }
    let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735') }
    let!(:base_city) { create(:city, tenant:, name: 'Ipatinga', state: 'MG', base: true) }
    let!(:away_city) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }

    before do
      manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 20, 8), closed_at: Time.zone.local(2026, 11, 24, 18))
      transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      create(:atua_transport_document, driver_code: 501)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 25), city: base_city)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 26), city: away_city)
      create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 11, 23))
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 30))
    end

    it 'marks the trip days, the days off and the leaves of each employee' do
      rows = schedule.rows(tenant.employees.preload(:driver).order(:name))

      expect(rows.map { |row| [row.employee.name, row.days.map(&:status)] }).to eq(
        [
          ['ANA PAULA', %i[work leave work work work work work]],
          ['JOSE SILVA', %i[trip trip trip day_off day_off work work]],
        ],
      )
      expect(rows.last.days[3].city).to eq(base_city)
      expect(rows.first.days[1].leave_reason_type).to eq('medical_certificate')
    end

    it 'counts the days off owed in the week' do
      ana_row, jose_row = schedule.rows(tenant.employees.preload(:driver).order(:name))

      expect([ana_row.days_off_count, ana_row.owed_days_off]).to eq([0, 2])
      expect([jose_row.days_off_count, jose_row.owed_days_off]).to eq([2, 0])
    end

    context 'when the trip is still in progress' do
      before do
        manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 27, 6), closed_at: nil)
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      end

      it 'marks the days up to today' do
        travel_to Date.new(2026, 11, 28) do
          jose_row = schedule.rows(tenant.employees.where(id: jose.id).preload(:driver)).sole

          expect(jose_row.days.last(2).map(&:status)).to eq(%i[trip trip])
        end
      end
    end
  end

  describe 'Sunday rule' do
    let!(:ana) { create(:employee, tenant:, name: 'ANA', legal_id: '00000000001', gender_type: 'female') }
    let!(:maria) { create(:employee, tenant:, name: 'MARIA', legal_id: '00000000002', gender_type: 'female') }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE', legal_id: '00000000003', gender_type: 'male') }
    let!(:pedro) { create(:employee, tenant:, name: 'PEDRO', legal_id: '00000000004', gender_type: 'male') }
    let!(:carlos) do
      create(:employee, tenant:, name: 'CARLOS', legal_id: '00000000005', gender_type: 'male', driver: create(:driver, tenant:, code: 777))
    end
    let!(:lucas) { create(:employee, tenant:, name: 'LUCAS', legal_id: '00000000006', gender_type: 'male') }
    let!(:city) { create(:city, tenant:) }

    before do
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 8), city:)
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 10), city:)
      create(:work_schedule_day, employee: maria, date: Date.new(2026, 11, 1), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 1), city:)
      create(:work_schedule_day, employee: pedro, date: Date.new(2026, 11, 22), city:)
      create(:work_schedule_day, employee: carlos, date: Date.new(2026, 10, 25), city:)
      create(:work_schedule_day, :leave, employee: lucas, date: Date.new(2026, 11, 15))
      create(:work_schedule_day, employee: lucas, date: Date.new(2026, 11, 29), city:)
      manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 21, 8), closed_at: Time.zone.local(2026, 11, 23, 18))
      transport_document = create(:atua_transport_document, tenant:, driver_code: 777)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
    end

    it 'gives the status of the Sunday off of each employee in the week' do
      rows = schedule.rows(tenant.employees.preload(:driver).order(:name))

      expect(rows.map { |row| [row.employee.name, row.sunday.status, row.sunday.last_on, row.sunday.due_on] }).to eq(
        [
          ['ANA', :due, Date.new(2026, 11, 8), Date.new(2026, 11, 22)],
          ['CARLOS', :overdue, Date.new(2026, 10, 25), Date.new(2026, 11, 22)],
          ['JOSE', :on_track, Date.new(2026, 11, 1), Date.new(2026, 11, 29)],
          ['LUCAS', :unknown, nil, nil],
          ['MARIA', :overdue, Date.new(2026, 11, 1), Date.new(2026, 11, 15)],
          ['PEDRO', :taken, Date.new(2026, 11, 22), Date.new(2026, 12, 20)],
        ],
      )
    end
  end

  describe 'alerts' do
    let!(:city) { create(:city, tenant:) }
    let!(:ana) { create(:employee, tenant:, name: 'ANA', legal_id: '00000000001', gender_type: 'male') }
    let!(:bruno) { create(:employee, tenant:, name: 'BRUNO', legal_id: '00000000002', gender_type: 'male') }
    let!(:carlos) do
      create(:employee, tenant:, name: 'CARLOS', legal_id: '00000000003', gender_type: 'male', driver: create(:driver, tenant:, code: 777))
    end
    let!(:jose) { create(:employee, tenant:, name: 'JOSE', legal_id: '00000000004', gender_type: 'male') }
    let!(:maria) { create(:employee, tenant:, name: 'MARIA', legal_id: '00000000005', gender_type: 'female') }

    before do
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 22), city:)
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 17), city:)
      (26..28).each { |day| create(:work_schedule_day, :leave, employee: bruno, date: Date.new(2026, 11, day)) }
      create(:work_schedule_day, employee: carlos, date: Date.new(2026, 11, 22), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 15), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 16), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 22), city:)
      create(:work_schedule_day, employee: maria, date: Date.new(2026, 11, 1), city:)
      create(:work_schedule_day, employee: maria, date: Date.new(2026, 11, 23), city:)
      create(:work_schedule_day, employee: maria, date: Date.new(2026, 11, 27), city:)
      manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 24, 8),
                                        closed_at: Time.zone.local(2026, 11, 28, 18))
      transport_document = create(:atua_transport_document, tenant:, driver_code: 777)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
    end

    def alerts_of(week)
      described_class.new(tenant:, week:).rows(tenant.employees.preload(:driver).order(:name)).map { |row| [row.employee.name, row.alerts] }
    end

    it 'warns in the current week only when the days left cannot fit the days off owed' do
      travel_to Date.new(2026, 11, 25) do
        expect(alerts_of('2026-11-25')).to eq(
          [
            ['ANA', []],
            ['BRUNO', [:few_days_off]],
            ['CARLOS', [:few_days_off]],
            ['JOSE', []],
            ['MARIA', [:sunday_overdue]],
          ],
        )
      end
    end

    it 'warns every employee with less than two days off in a past week' do
      travel_to Date.new(2026, 11, 25) do
        expect(alerts_of('2026-11-15')).to eq(
          [
            ['ANA', [:few_days_off]],
            ['BRUNO', [:few_days_off]],
            ['CARLOS', [:few_days_off]],
            ['JOSE', []],
            ['MARIA', [:few_days_off]],
          ],
        )
      end
    end

    it 'does not warn about the days off of a future week' do
      travel_to Date.new(2026, 11, 25) do
        expect(alerts_of('2026-11-29').to_h.values.flatten).not_to include(:few_days_off)
      end
    end

    it 'counts and filters the rows by alert' do
      travel_to Date.new(2026, 11, 25) do
        schedule = described_class.new(tenant:, week: '2026-11-25')
        rows = schedule.rows(tenant.employees.preload(:driver).order(:name))

        expect(schedule.alert_counts(rows)).to eq(few_days_off: 2, sunday_overdue: 1, any: 3)
        expect(schedule.with_alert(rows, 'any').map { |row| row.employee.name }).to eq(%w[BRUNO CARLOS MARIA])
        expect(schedule.with_alert(rows, 'sunday_overdue').map { |row| row.employee.name }).to eq(%w[MARIA])
        expect(schedule.with_alert(rows, 'unknown').size).to eq(5)
        expect(schedule.with_alert(rows, nil).size).to eq(5)
      end
    end
  end

  describe '#employees' do
    let!(:scheduled) { create(:employee, tenant:, legal_id: '52998224725') }

    before do
      create(:employee, tenant:, legal_id: '11144477735', work_schedule_type: 'not_scheduled')
      create(:employee, legal_id: '39053344705')
    end

    it 'lists the active 5x2 employees of the tenant' do
      expect(schedule.employees).to eq([scheduled])
    end
  end
end
