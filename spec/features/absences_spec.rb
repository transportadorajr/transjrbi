require 'rails_helper'

describe 'Absences', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Férias', slug: 'vacations') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', nickname: 'ZÉ', legal_id: '52998224725', admitted_on: Date.new(2024, 3, 10)) }
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735') }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  before do
    create(:vacation, employee: jose, start_on: Date.new(2026, 11, 2), end_on: Date.new(2026, 11, 21))
    create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 11, 10))
    create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 11, 11))
    stranger = create(:employee, tenant: create(:tenant), name: 'FUNCIONÁRIO DE OUTRA', admitted_on: Date.new(2024, 3, 10))
    create(:vacation, employee: stranger, start_on: Date.new(2026, 11, 2), end_on: Date.new(2026, 11, 21))
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'shows who is out in the month from the HR menu' do
      visit absences_path
      within('.sidebar-desktop') { click_on 'Quem está fora' }

      expect(page).to have_css('.page-header', text: 'Novembro de 2026')
      expect(Vacation.count).to eq(2)
      expect(WorkScheduleDay.count).to eq(2)
      expect(page).to have_css('.card', text: "Funcionários fora no mês\n2")
      within('#absence_calendar') do
        expect(page).to have_css('.absence-calendar-cell', text: "2\nZÉ")
        expect(page).to have_css('.absence-calendar-cell', text: /\A10\nZÉ\s*ANA PAULA\z/)
        expect(page).to have_css('.absence-calendar-cell', text: /\A22\z/)
      end
      expect(html_table_to_rows).to eq(
        [
          ['Funcionário', 'Motivo', 'Período', 'Dias no mês'],
          ['JOSE SILVA', 'Férias', '02/11/2026 a 21/11/2026', '20'],
          ['ANA PAULA', 'Afastamento (Atestado médico)', '10/11/2026 a 11/11/2026', '2'],
        ],
      )
      expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
    end

    context 'when there are absences in the next months' do
      before do
        create(:vacation, employee: ana, acquisition_start_on: Date.new(2026, 1, 7), start_on: Date.new(2027, 1, 7), end_on: Date.new(2027, 2, 5))
        create(:vacation, employee: jose, start_on: Date.new(2026, 12, 20), end_on: Date.new(2027, 1, 18))
        create(:vacation, employee: jose, start_on: Date.new(2027, 3, 1), end_on: Date.new(2027, 3, 30))
        create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 12, 3))
      end

      scenario 'lists who leaves in the next three months' do
        visit absences_path

        expect(Vacation.count).to eq(5)
        expect(WorkScheduleDay.count).to eq(3)
        expect(page).to have_text('Saídas de dezembro de 2026 a fevereiro de 2027, 3 registros.')
        expect(html_table_to_rows(table: find_by_id('upcoming_absences'))).to eq(
          [
            ['Funcionário', 'Motivo', 'Período', 'Dias'],
            ['ANA PAULA', 'Afastamento (Atestado médico)', '03/12/2026 a 03/12/2026', '1'],
            ['JOSE SILVA', 'Férias', '20/12/2026 a 18/01/2027', '30'],
            ['ANA PAULA', 'Férias', '07/01/2027 a 05/02/2027', '30'],
          ],
        )
      end

      scenario 'moves the next months along with the month' do
        visit absences_path(month: '2026-12')

        expect(page).to have_text('Saídas de janeiro de 2027 a março de 2027, 2 registros.')
        expect(html_table_to_rows(table: find_by_id('upcoming_absences'))).to eq(
          [
            ['Funcionário', 'Motivo', 'Período', 'Dias'],
            ['ANA PAULA', 'Férias', '07/01/2027 a 05/02/2027', '30'],
            ['JOSE SILVA', 'Férias', '01/03/2027 a 30/03/2027', '30'],
          ],
        )
      end
    end

    scenario 'moves to the next month' do
      visit absences_path
      click_on 'Próximo mês'

      expect(page).to have_current_path(absences_path(month: '2026-12'))
      expect(page).to have_css('.page-header', text: 'Dezembro de 2026')
      expect(page).to have_text('Nenhum registro encontrado')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'lists only the days with someone out instead of the calendar' do
      visit absences_path

      expect(page).to have_css('#absence_day_list li', count: 20)
      expect(page).to have_css('#absence_day_list li', text: "10/11/2026 (terça-feira)\nZÉ\nANA PAULA")
      expect(page).to have_no_css('#absence_calendar')
    end

    scenario 'lists the next months with the employee and the period only' do
      create(:vacation, employee: ana, acquisition_start_on: Date.new(2026, 1, 7), start_on: Date.new(2027, 1, 7), end_on: Date.new(2027, 2, 5))

      visit absences_path

      expect(Vacation.count).to eq(3)
      expect(html_table_to_rows(table: find_by_id('upcoming_absences')).map { |row| row.reject(&:empty?) }).to eq(
        [
          %w[FUNCIONÁRIO PERÍODO],
          ['ANA PAULA', '07/01/2027 a 05/02/2027'],
        ],
      )
    end
  end
end
