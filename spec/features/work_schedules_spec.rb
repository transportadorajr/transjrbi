require 'rails_helper'

describe 'Work schedules', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Escala de folgas', slug: 'work_schedules') }

  around { |example| travel_to(Time.zone.local(2026, 11, 25, 10)) { example.run } }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the schedule to the login screen' do
      visit work_schedules_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the HR flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the schedule' do
      visit work_schedules_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no employees in the schedule' do
      before { create(:employee, tenant:, work_schedule_type: 'not_scheduled') }

      scenario 'shows the empty state message' do
        visit work_schedules_path

        expect(Employee.count).to eq(1)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when an employee is on vacation' do
      let!(:maria) { create(:employee, tenant:, name: 'MARIA LIMA', legal_id: '11144477735', admitted_on: Date.new(2025, 1, 5)) }

      before { create(:vacation, employee: maria, start_on: Date.new(2026, 11, 25), end_on: Date.new(2026, 12, 14)) }

      scenario 'shows the vacation days on the schedule without warnings' do
        visit work_schedules_path

        expect(Vacation.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'dom 22/11', 'seg 23/11', 'ter 24/11', 'qua 25/11', 'qui 26/11', 'sex 27/11', 'sáb 28/11', 'Folgas na semana', 'Domingo de folga',
             'Avisos', 'Ações'],
            ['MARIA LIMA', 'Trabalho', 'Trabalho', 'Trabalho', 'Férias', 'Férias', 'Férias', 'Férias', '0 de 2 folgas', 'Sem domingo registrado', '', ''],
          ],
        )
      end
    end

    context 'when there are employees in the schedule' do
      let!(:driver) { create(:driver, tenant:, code: 501) }
      let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', company_type: 'transjr', driver:) }
      let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme') }
      let!(:base_city) { create(:city, tenant:, name: 'Ipatinga', state: 'MG', base: true) }
      let!(:away_city) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }

      before do
        create(:employee, tenant:, name: 'FORA DA ESCALA', legal_id: '39053344705', work_schedule_type: 'not_scheduled')
        create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA')
        manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 20, 8),
                                          closed_at: Time.zone.local(2026, 11, 24, 18))
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
        create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 25), city: base_city)
        create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 26), city: away_city)
        create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 11, 23))
      end

      scenario 'shows the week from the HR menu' do
        visit employees_path
        within('.sidebar-desktop') { click_on 'Escala de folgas' }

        expect(page).to have_current_path(work_schedules_path)
        expect(page).to have_css('.page-header', text: 'Semana de 22/11/2026 a 28/11/2026')
        expect(Employee.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'dom 22/11', 'seg 23/11', 'ter 24/11', 'qua 25/11', 'qui 26/11', 'sex 27/11', 'sáb 28/11', 'Folgas na semana', 'Domingo de folga', 'Avisos',
             'Ações'],
            ['ANA PAULA', 'Trabalho', 'AfastamentoAtestado médico', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho',
             '0 de 2 folgas', 'Sem domingo registrado', '', ''],
            ['JOSE SILVA', 'Em viagem', 'Em viagem', 'Em viagem', 'Folga na baseIpatinga/MG', 'Folga fora da baseCubatão/SP',
             'Trabalho', 'Trabalho', '2 de 2 folgas', 'Sem domingo registrado', '', ''],
          ],
        )
        expect(page).to have_no_text('FORA DA ESCALA')
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'exports the week to a landscape PDF' do
        visit work_schedules_path(week: '2026-11-22')

        expect(page).to have_link('Exportar PDF', href: work_schedules_path(week: '2026-11-22', format: :pdf))

        visit work_schedules_path(week: '2026-11-22', format: :pdf)

        text = PDF::Inspector::Text.analyze(page.body).strings.join
        width, height = PDF::Inspector::Page.analyze(page.body).pages.first[:size]
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(width).to be > height
        expect(Employee.count).to eq(4)
        expect(text).to include('Relatório da Escala de Folgas', 'Semana de 22/11/2026 a 28/11/2026', 'ANA PAULA', 'JOSE SILVA',
                                'Em viagem', 'Afastamento', 'Sem domingo registrado', '2 registros listados.')
        expect(text).not_to include('FORA DA ESCALA', 'FUNCIONÁRIO DE OUTRA')
      end

      scenario 'exports the week to Excel', :xlsx_service, flipper: { hr: :tenant, xlsx_export: :tenant } do
        visit work_schedules_path(name: 'silva')
        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include('attachment', "escala-de-folgas-#{Date.current.iso8601}.xlsx")
        expect(Employee.count).to eq(4)
        expect(downloaded_xlsx_rows).to eq(
          [
            ['Nome', 'Empresa', 'dom 22/11', 'seg 23/11', 'ter 24/11', 'qua 25/11', 'qui 26/11', 'sex 27/11', 'sáb 28/11', 'Folgas na semana',
             'Domingo de folga', 'Avisos'],
            ['JOSE SILVA', 'TransJR', 'Em viagem', 'Em viagem', 'Em viagem', 'Folga na base (Ipatinga/MG)', 'Folga fora da base (Cubatão/SP)',
             'Trabalho', 'Trabalho', 2, 'Sem domingo registrado', nil],
          ],
        )
      end

      scenario 'moves to the next and back to the current week' do
        visit work_schedules_path
        click_on 'Próxima semana'

        expect(page).to have_current_path(work_schedules_path(week: '2026-11-29'))
        expect(page).to have_css('.page-header', text: 'Semana de 29/11/2026 a 05/12/2026')
        expect(Employee.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'dom 29/11', 'seg 30/11', 'ter 01/12', 'qua 02/12', 'qui 03/12', 'sex 04/12', 'sáb 05/12', 'Folgas na semana', 'Domingo de folga', 'Avisos',
             'Ações'],
            ['ANA PAULA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', '0 de 2 folgas', 'Sem domingo registrado',
             '', ''],
            ['JOSE SILVA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', '0 de 2 folgas', 'Sem domingo registrado',
             '', ''],
          ],
        )

        click_on 'Esta semana'

        expect(page).to have_css('.page-header', text: 'Semana de 22/11/2026 a 28/11/2026')
      end

      scenario 'filters the employees keeping the week' do
        visit work_schedules_path(week: '2026-11-18')
        fill_in 'Nome', with: 'silva'
        select 'TransJR', from: 'Empresa'
        click_on 'Aplicar Filtros'

        expect(page).to have_css('.page-header', text: 'Semana de 15/11/2026 a 21/11/2026')
        expect(Employee.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'dom 15/11', 'seg 16/11', 'ter 17/11', 'qua 18/11', 'qui 19/11', 'sex 20/11', 'sáb 21/11', 'Folgas na semana', 'Domingo de folga', 'Avisos',
             'Ações'],
            ['JOSE SILVA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Em viagem', 'Em viagem', '0 de 2 folgas', 'Sem domingo registrado',
             'Menos de 2 folgas', ''],
          ],
        )
      end
    end
  end

  context 'when the employees have Sunday deadlines', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:city) { create(:city, tenant:) }

    before do
      ana = create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', gender_type: 'female')
      jose = create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', gender_type: 'male')
      create(:employee, tenant:, name: 'PEDRO ALVES', legal_id: '39053344705', gender_type: 'male')
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 1), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 8), city:)
      login_as(owner, scope: :user)
    end

    scenario 'shows the Sunday off status of each employee' do
      visit work_schedules_path

      expect(Employee.count).to eq(3)
      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'dom 22/11', 'seg 23/11', 'ter 24/11', 'qua 25/11', 'qui 26/11', 'sex 27/11', 'sáb 28/11', 'Folgas na semana',
           'Domingo de folga', 'Avisos', 'Ações'],
          ['ANA PAULA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', '0 de 2 folgas', 'Atrasado desde 15/11',
           'Domingo atrasado', ''],
          ['JOSE SILVA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', '0 de 2 folgas', 'Próximo até 06/12', '', ''],
          ['PEDRO ALVES', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', '0 de 2 folgas', 'Sem domingo registrado',
           '', ''],
        ],
      )
    end
  end

  context 'when the employees have schedule alerts', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:city) { create(:city, tenant:) }
    let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', gender_type: 'female') }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', gender_type: 'male') }
    let!(:pedro) { create(:employee, tenant:, name: 'PEDRO ALVES', legal_id: '39053344705', gender_type: 'male') }

    before do
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 1), city:)
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 8), city:)
      (26..28).each { |day| create(:work_schedule_day, :leave, employee: ana, date: Date.new(2026, 11, day)) }
      (25..28).each { |day| create(:work_schedule_day, :leave, employee: pedro, date: Date.new(2026, 11, day)) }
      login_as(owner, scope: :user)
    end

    scenario 'counts the employees with each alert of the week' do
      visit work_schedules_path

      expect(Employee.count).to eq(3)
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(
        ['Funcionários com aviso 2', 'Menos de 2 folgas na semana 2', 'Semana em viagem sem folga 0', 'Domingo de folga atrasado 1',
         'Folgas acumuladas após semanas sem folga 0', 'Escala da próxima semana não lançada 0'],
      )
      expect(html_table_to_rows.map { |row| [row.first, row[-2]] }).to eq(
        [
          %w[Nome Avisos],
          ['ANA PAULA', 'Menos de 2 folgasDomingo atrasado'],
          ['JOSE SILVA', ''],
          ['PEDRO ALVES', 'Menos de 2 folgas'],
        ],
      )
    end

    scenario 'filters the employees by alert keeping the counters of the whole week' do
      visit work_schedules_path
      select 'Domingo atrasado', from: 'Aviso'
      click_on 'Aplicar Filtros'

      expect(page).to have_css('.page-header', text: 'Semana de 22/11/2026 a 28/11/2026')
      expect(Employee.count).to eq(3)
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(
        ['Funcionários com aviso 2', 'Menos de 2 folgas na semana 2', 'Semana em viagem sem folga 0', 'Domingo de folga atrasado 1',
         'Folgas acumuladas após semanas sem folga 0', 'Escala da próxima semana não lançada 0'],
      )
      expect(html_table_to_rows.map(&:first)).to eq(['Nome', 'ANA PAULA'])
      expect(page).to have_text('1 registro')

      select 'Com qualquer aviso', from: 'Aviso'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows.map(&:first)).to eq(['Nome', 'ANA PAULA', 'PEDRO ALVES'])
    end

    scenario 'lists the alerts in the PDF export' do
      visit work_schedules_path(format: :pdf)

      text = PDF::Inspector::Text.analyze(page.body).strings.join
      expect(Employee.count).to eq(3)
      expect(text).to include('Avisos', 'Menos de 2 folgas, Domingo atrasado')
    end
  end

  context 'when a driver travels the whole week and another piles up days off', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:city) { create(:city, tenant:) }

    before do
      jose = create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', driver: create(:driver, tenant:, code: 501))
      ana = create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735')
      manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 22, 8),
                                        closed_at: Time.zone.local(2026, 11, 28, 18))
      transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      create(:work_schedule_day, :leave, employee: jose, date: Date.new(2026, 10, 25))
      [Date.new(2026, 11, 1), Date.new(2026, 11, 2), *(23..25).map { |day| Date.new(2026, 11, day) }].each do |date|
        create(:work_schedule_day, employee: ana, date:, city:)
      end
      login_as(owner, scope: :user)
    end

    scenario 'shows the trip week and the accumulated days off alerts' do
      visit work_schedules_path

      expect(Employee.count).to eq(2)
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(
        ['Funcionários com aviso 2', 'Menos de 2 folgas na semana 0', 'Semana em viagem sem folga 1', 'Domingo de folga atrasado 0',
         'Folgas acumuladas após semanas sem folga 1', 'Escala da próxima semana não lançada 0'],
      )
      expect(html_table_to_rows.map { |row| [row.first, row[-2]] }).to eq(
        [
          %w[Nome Avisos],
          ['ANA PAULA', 'Folgas acumuladas'],
          ['JOSE SILVA', 'Semana em viagem sem folga'],
        ],
      )
    end

    scenario 'filters the drivers on a trip week without a day off' do
      visit work_schedules_path
      select 'Semana em viagem sem folga', from: 'Aviso'
      click_on 'Aplicar Filtros'

      expect(Employee.count).to eq(2)
      expect(html_table_to_rows.map(&:first)).to eq(['Nome', 'JOSE SILVA'])
    end
  end

  context 'when it is Thursday and the next week is not entered for everyone', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:city) { create(:city, tenant:) }

    before do
      ana = create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735')
      create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725')
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 11, 30), city:)
      create(:work_schedule_day, employee: ana, date: Date.new(2026, 12, 1), city:)
      login_as(owner, scope: :user)
    end

    scenario 'warns about the employees without the days off of next week' do
      travel_to(Time.zone.local(2026, 11, 26, 10))

      visit work_schedules_path

      expect(Employee.count).to eq(2)
      expect(all('.counter-card').map { |card| card.text.squish }.last).to eq('Escala da próxima semana não lançada 1')
      expect(html_table_to_rows.map { |row| [row.first, row[-2]] }).to eq(
        [
          %w[Nome Avisos],
          ['ANA PAULA', ''],
          ['JOSE SILVA', 'Próxima semana não lançada'],
        ],
      )

      select 'Próxima semana não lançada', from: 'Aviso'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows.map(&:first)).to eq(['Nome', 'JOSE SILVA'])

      click_on 'Próxima semana'

      expect(page).to have_css('.page-header', text: 'Semana de 29/11/2026 a 05/12/2026')
      expect(page).to have_text('Nenhum registro encontrado')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA') }

    before do
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 25))
      (26..28).each { |day| create(:work_schedule_day, :leave, employee: jose, date: Date.new(2026, 11, day)) }
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'shows a card per employee instead of the table' do
      visit work_schedules_path

      within("#card_employee_#{jose.id}") do
        expect(page).to have_text('JOSE SILVA')
        expect(page).to have_text('1 de 2 folgas')
        expect(page).to have_text('Sem domingo registrado')
        expect(page).to have_text('Menos de 2 folgas')
        expect(page).to have_text('Folga')
      end
      expect(page).to have_no_css('#work_schedule_table')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when a user without access to the schedule is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:access, user: operator, resource: hr_resource, creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'does not see the schedule' do
      visit work_schedules_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(page).to have_no_css('#work_schedule_table')
    end
  end
end
