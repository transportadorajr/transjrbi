require 'rails_helper'

describe 'Uninsured employees', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Seguro de vida', slug: 'life_insurances') }
  let!(:employees_resource) { create(:resource, name: 'Funcionários', slug: 'employees') }
  let!(:mme_policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
  let!(:driver_position) { create(:job_position, tenant:, name: 'MOTORISTA DE CARRETA') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', company_type: 'mme') }
  let!(:ana) do
    create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mm_espinola', registration: '00042',
                      job_position: driver_position, admitted_on: Date.new(2025, 2, 10))
  end
  let!(:carlos) { create(:employee, tenant:, name: 'CARLOS LIMA', legal_id: '39053344705', company_type: 'mme') }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  before do
    create(:life_insurance, employee: jose, life_insurance_policy: mme_policy, included_on: Date.new(2026, 1, 5))
    create(:life_insurance, employee: carlos, life_insurance_policy: mme_policy, excluded_on: Date.new(2026, 11, 1))
    create(:employee, tenant:, name: 'INATIVO SEM SEGURO', legal_id: '86288366757', activated: false)
    create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA')
  end

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit uninsured_employees_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'lists the active employees without life insurance from the HR menu' do
      visit life_insurances_path
      within('.sidebar-desktop') { click_on 'Sem seguro de vida' }

      expect(page).to have_current_path(uninsured_employees_path)
      expect(Employee.count).to eq(5)
      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Empresa', 'Cargo', 'Data de admissão', 'Ações'],
          ['ANA PAULA', 'MM Espinola', 'MOTORISTA DE CARRETA', '10/02/2025', 'Opções Visualizar Incluir no seguro'],
          ['CARLOS LIMA', 'MME', 'Sem cargo', '-', 'Opções Visualizar Incluir no seguro'],
        ],
      )
      expect(page).to have_no_text('JOSE SILVA')
      expect(page).to have_no_text('INATIVO SEM SEGURO')
      expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
    end

    scenario 'opens the uninsured employees from the life insurance screen' do
      visit life_insurances_path
      within('.page-header') { click_on 'Sem seguro de vida' }

      expect(page).to have_current_path(uninsured_employees_path)
    end

    scenario 'filters the uninsured employees by name and company' do
      visit uninsured_employees_path(company_type: 'mme')

      expect(Employee.count).to eq(5)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['CARLOS LIMA'])

      visit uninsured_employees_path(name: 'ana')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['ANA PAULA'])
    end

    scenario 'sorts the uninsured employees by name' do
      visit uninsured_employees_path(sort: 'name', direction: 'desc')

      expect(Employee.count).to eq(5)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['CARLOS LIMA', 'ANA PAULA'])
    end

    scenario 'opens the page of an uninsured employee' do
      visit uninsured_employees_path
      within("#employee_#{ana.id}") { click_on 'Visualizar', match: :first }

      expect(page).to have_current_path(employee_path(ana))
      expect(dl_to_hash('#life_insurance dl')).to eq('Situação' => 'Sem seguro')
    end

    scenario 'shows the coverages on the page of an insured employee' do
      visit employee_path(jose)

      expect(dl_to_hash('#life_insurance dl')).to eq(
        'Situação' => 'Segurado', 'Capital segurado' => 'R$ 115.000,00', 'Morte acidental' => 'R$ 115.000,00',
        'Invalidez permanente por acidente' => 'R$ 115.000,00', 'Invalidez funcional por doença' => 'R$ 115.000,00',
        'Morte do cônjuge' => 'R$ 57.500,00', 'Morte de filhos' => 'R$ 11.500,00', 'Assistência funeral familiar' => 'R$ 6.000,00',
        'Prêmio' => 'R$ 36,63', 'Inclusão' => '05/01/2026'
      )
    end

    scenario 'exports the uninsured employees to PDF' do
      visit uninsured_employees_path(format: :pdf)

      text = PDF::Inspector::Text.analyze(page.body).strings.join
      expect(page.response_headers['Content-Type']).to include('application/pdf')
      expect(Employee.count).to eq(5)
      expect(text).to include('Relatório dos Funcionários sem Seguro de Vida', 'ANA PAULA', 'CARLOS LIMA', 'MOTORISTA DE CARRETA', '10/02/2025')
      expect(text).not_to include('JOSE SILVA', 'INATIVO SEM SEGURO', 'FUNCIONÁRIO DE OUTRA')
    end

    scenario 'exports the uninsured employees to Excel', :xlsx_service, flipper: { hr: :tenant, xlsx_export: :tenant } do
      visit uninsured_employees_path(company_type: 'mm_espinola')
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', "sem-seguro-de-vida-#{Date.current.iso8601}.xlsx")
      expect(downloaded_xlsx_rows).to eq(
        [
          ['Nome', 'Empresa', 'Matrícula', 'Cargo', 'Data de admissão'],
          ['ANA PAULA', 'MM Espinola', '00042', 'MOTORISTA DE CARRETA', Date.new(2025, 2, 10)],
        ],
      )
    end

    context 'when every active employee is insured' do
      before do
        create(:life_insurance, employee: ana, life_insurance_policy: create(:life_insurance_policy, tenant:, company_type: 'mm_espinola'))
        create(:life_insurance, employee: carlos, life_insurance_policy: mme_policy)
      end

      scenario 'shows the empty listing' do
        visit uninsured_employees_path

        expect(Employee.count).to eq(5)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the name and the actions without scrolling sideways' do
      visit uninsured_employees_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'EMPRESA')
      expect(page).to have_no_css('th', text: 'CARGO')

      within("#employee_#{ana.id}") do
        click_button 'Opções'
        click_on 'Visualizar'
      end

      expect(page).to have_current_path(employee_path(ana))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
