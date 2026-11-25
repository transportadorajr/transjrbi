require 'rails_helper'

describe 'HR pendencies', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resources) do
    %w[hr hr_pendencies employees life_insurances emergency_contacts risk_assessments vacations work_schedules]
      .index_with { |slug| create(:resource, slug:) }
  end
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme') }
  let!(:bruno) { create(:employee, tenant:, name: 'BRUNO COSTA', legal_id: '52998224725', company_type: 'mme') }
  let!(:carlos) { create(:employee, tenant:, name: 'CARLOS LIMA', legal_id: '39053344705', company_type: 'mm_espinola') }
  let!(:edson) do
    create(:employee, tenant:, name: 'EDSON ROCHA', legal_id: '86288366757', company_type: 'mm_espinola', admitted_on: Date.new(2024, 10, 1))
  end

  around { |example| travel_to(Time.zone.local(2026, 11, 25, 10)) { example.run } }

  before do
    [ana, carlos, edson].each { |employee| create(:life_insurance, employee:) }
    [ana, bruno, edson].each { |employee| create(:emergency_contact, employee:) }
    create(:risk_assessment, employee: carlos, valid_until: Date.new(2026, 11, 20))
    create(:employee, tenant:, name: 'INATIVO SEM SEGURO', legal_id: nil, activated: false)
    create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA')
  end

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the panel to the login screen' do
      visit hr_pendencies_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'lands on the panel when entering the HR module' do
      visit '/'

      expect(page).to have_current_path(hr_pendencies_path)
      expect(page).to have_css('h1.page-title', text: 'Pendências do RH')
    end

    scenario 'lists the active employees with pendencies from the HR menu' do
      visit employees_path
      within('.sidebar-desktop') { click_on 'Pendências' }

      expect(page).to have_current_path(hr_pendencies_path)
      expect(Employee.count).to eq(6)
      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Empresa', 'Pendências', 'Ações'],
          ['BRUNO COSTA', 'MME', 'Sem seguro de vida', ''],
          ['CARLOS LIMA', 'MM Espinola', 'Sem contato de emergência Pesquisa vencida', ''],
          ['EDSON ROCHA', 'MM Espinola', 'Férias vencidas', ''],
        ],
      )
      expect(page).to have_no_text('ANA PAULA')
      expect(page).to have_no_text('INATIVO SEM SEGURO')
      expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
    end

    scenario 'counts the employees of each pendency' do
      visit hr_pendencies_path

      expect(all('.counter-card').map { |card| card.text.squish }).to eq(
        [
          'Sem seguro de vida 1', 'Sem contato de emergência 1', 'Pesquisa vencida 1', 'Pesquisa vence em até 30 dias 0',
          'Férias vencidas 1', 'Férias vencem em até 60 dias 0', 'Folgas irregulares 0'
        ],
      )
    end

    scenario 'filters the employees by pendency, name and company' do
      visit hr_pendencies_path(pendency: 'risk_assessment_expired')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['CARLOS LIMA'])

      visit hr_pendencies_path(name: 'edson')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['EDSON ROCHA'])

      visit hr_pendencies_path(company_type: 'mme')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['BRUNO COSTA'])
    end

    scenario 'sorts the employees by name' do
      visit hr_pendencies_path(sort: 'name', direction: 'desc')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['EDSON ROCHA', 'CARLOS LIMA', 'BRUNO COSTA'])
    end

    scenario 'opens the page of an employee with pendencies' do
      visit hr_pendencies_path
      within("#employee_#{bruno.id}") { click_on 'Visualizar' }

      expect(page).to have_current_path(employee_path(bruno))
    end

    scenario 'opens the screen where a pendency is solved' do
      visit hr_pendencies_path
      within("#employee_#{carlos.id}") { click_on 'Sem contato de emergência' }

      expect(page).to have_current_path(emergency_contacts_path(name: 'CARLOS LIMA', contact: 'missing'))

      visit hr_pendencies_path
      within("#employee_#{edson.id}") { click_on 'Férias vencidas' }

      expect(page).to have_current_path(vacation_balances_path(name: 'EDSON ROCHA', status: 'overdue'))
    end

    context 'when every active employee is up to date' do
      before do
        create(:life_insurance, employee: bruno)
        create(:emergency_contact, employee: carlos)
        RiskAssessment.update_all(valid_until: Date.new(2027, 5, 11))
        create(:vacation, employee: edson, acquisition_start_on: Date.new(2024, 10, 1), start_on: Date.new(2025, 11, 1),
                          end_on: Date.new(2025, 11, 30))
      end

      scenario 'shows the empty panel' do
        visit hr_pendencies_path

        expect(Employee.count).to eq(6)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end
  end

  context 'when a user reads only some screens of the HR module', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      %w[hr hr_pendencies life_insurances].each { |slug| create(:access, user: operator, resource: resources[slug]) }
      login_as(operator, scope: :user)
    end

    scenario 'sees only the pendencies of the screens the user can read' do
      visit hr_pendencies_path

      expect(html_table_to_rows).to eq([['Nome', 'Empresa', 'Pendências', 'Ações'], ['BRUNO COSTA', 'MME', 'Sem seguro de vida', '']])
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Sem seguro de vida 1'])
    end
  end

  context 'when a user of the HR module cannot read the panel', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      %w[hr employees].each { |slug| create(:access, user: operator, resource: resources[slug]) }
      login_as(operator, scope: :user)
    end

    scenario 'does not open the panel' do
      visit hr_pendencies_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(page).to have_no_css('h1.page-title', text: 'Pendências do RH')
      expect(page).to have_no_link('Pendências')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the name and the pendencies without scrolling sideways' do
      visit hr_pendencies_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_css('th', text: 'PENDÊNCIAS')
      expect(page).to have_no_css('th', text: 'EMPRESA')

      within("#employee_#{bruno.id}") { click_on 'Visualizar' }

      expect(page).to have_current_path(employee_path(bruno))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
