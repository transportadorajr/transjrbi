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
            ['Nome', 'dom 22/11', 'seg 23/11', 'ter 24/11', 'qua 25/11', 'qui 26/11', 'sex 27/11', 'sáb 28/11', 'Folgas na semana'],
            ['ANA PAULA', 'Trabalho', 'AfastamentoAtestado médico', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho',
             '0 de 2 folgas'],
            ['JOSE SILVA', 'Em viagem', 'Em viagem', 'Em viagem', 'Folga na baseIpatinga/MG', 'Folga fora da baseCubatão/SP',
             'Trabalho', 'Trabalho', '2 de 2 folgas'],
          ],
        )
        expect(page).to have_no_text('FORA DA ESCALA')
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'moves to the next and back to the current week' do
        visit work_schedules_path
        click_on 'Próxima semana'

        expect(page).to have_current_path(work_schedules_path(week: '2026-11-29'))
        expect(page).to have_css('.page-header', text: 'Semana de 29/11/2026 a 05/12/2026')
        expect(html_table_to_rows.drop(1).map(&:last)).to eq(['0 de 2 folgas', '0 de 2 folgas'])

        click_on 'Esta semana'

        expect(page).to have_css('.page-header', text: 'Semana de 22/11/2026 a 28/11/2026')
      end

      scenario 'filters the employees keeping the week' do
        visit work_schedules_path(week: '2026-11-18')
        fill_in 'Nome', with: 'silva'
        select 'TransJR', from: 'Empresa'
        click_on 'Aplicar Filtros'

        expect(page).to have_css('.page-header', text: 'Semana de 15/11/2026 a 21/11/2026')
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'dom 15/11', 'seg 16/11', 'ter 17/11', 'qua 18/11', 'qui 19/11', 'sex 20/11', 'sáb 21/11', 'Folgas na semana'],
            ['JOSE SILVA', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Trabalho', 'Em viagem', 'Em viagem', '0 de 2 folgas'],
          ],
        )
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA') }

    before do
      create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 25))
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'shows a card per employee instead of the table' do
      visit work_schedules_path

      within("#card_employee_#{jose.id}") do
        expect(page).to have_text('JOSE SILVA')
        expect(page).to have_text('1 de 2 folgas')
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
