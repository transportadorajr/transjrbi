require 'rails_helper'

describe 'Employees', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Funcionários', slug: 'employees') }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit employees_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the HR flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit employees_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner opens the app', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    around do |example|
      Capybara.app_host = "http://#{Rails.application.config.x.app_host}"
      example.run
    end

    before { login_as(owner, scope: :user) }

    scenario 'does not open the employees out of the HR subdomain' do
      visit employees_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no employees' do
      scenario 'lands on the empty listing from the HR home' do
        visit '/'

        expect(page).to have_current_path(employees_path)
        expect(Employee.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are employees' do
      let!(:driver) { create(:driver, tenant:, code: 501) }
      let!(:jose) do
        create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', role: 'MOTORISTA', driver:)
      end
      let!(:ana) do
        create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme', gender_type: 'female',
                          role: 'AUXILIAR', work_schedule_type: 'not_scheduled', activated: false)
      end
      let!(:stranger) { create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA') }

      scenario 'lists the employees from the HR menu' do
        visit employees_path
        within('.sidebar-desktop') { click_on 'Funcionários' }

        expect(page).to have_current_path(employees_path)
        expect(Employee.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Empresa', 'Função', 'Escala', 'Motorista no Atua', 'Situação', 'Ações'],
            ['ANA PAULA', 'MME', 'AUXILIAR', 'Fora da escala', 'Não vinculado', 'Inativo', 'Opções Visualizar Alterar Ativar'],
            ['JOSE SILVA', 'TransJR', 'MOTORISTA', 'Escala 5x2', '501', 'Ativo', 'Opções Visualizar Alterar Inativar'],
          ],
        )
        expect(page).to have_link('Novo Funcionário', href: new_employee_path)
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'filters the employees' do
        visit employees_path
        fill_in 'Nome', with: 'silva'
        select 'TransJR', from: 'Empresa'
        select 'Escala 5x2', from: 'Escala'
        select 'Ativo', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Empresa', 'Função', 'Escala', 'Motorista no Atua', 'Situação', 'Ações'],
            ['JOSE SILVA', 'TransJR', 'MOTORISTA', 'Escala 5x2', '501', 'Ativo', 'Opções Visualizar Alterar Inativar'],
          ],
        )
      end

      scenario 'shows an employee' do
        mechanic = create(:workshop_employee, tenant:, name: 'ANA MECÂNICA')
        ana.update!(workshop_employee: mechanic, nickname: 'NINA', registration: '0042', cost_center: 'OFICINA',
                    born_on: Date.new(1990, 4, 12), admitted_on: Date.new(2020, 2, 3))

        visit employee_path(ana)

        expect(dl_to_hash('#employee_data')).to eq(
          'Nome' => 'ANA PAULA', 'Apelido' => 'NINA', 'CPF' => '111.444.777-35', 'Sexo' => 'Feminino',
          'Data de nascimento' => '12/04/1990', 'Empresa' => 'MME', 'Matrícula' => '0042', 'Data de admissão' => '03/02/2020',
          'Função' => 'AUXILIAR', 'Centro de custo' => 'OFICINA', 'Escala' => 'Fora da escala',
          'Motorista no Atua' => 'Não vinculado', 'Funcionário da oficina' => 'ANA MECÂNICA', 'Situação' => 'Inativo'
        )
      end

      scenario 'edits an employee' do
        visit employee_path(jose)
        click_on 'Alterar'

        fill_in 'Apelido', with: 'Zé'
        select 'Fora da escala', from: 'Escala'

        expect { click_on 'Salvar Alterações' }.not_to change(Employee, :count)

        expect(page).to have_current_path(employee_path(jose))
        expect(page).to have_text('Funcionário atualizado com sucesso.')
        expect(jose.reload).to have_attributes(nickname: 'ZÉ', work_schedule_type: 'not_scheduled', driver_code: nil)
      end

      scenario 'deactivates an employee from the listing' do
        visit employees_path

        expect { page.driver.submit :patch, deactivate_employee_path(jose), {} }.not_to change(Employee, :count)

        expect(page).to have_text('Registro inativado com sucesso.')
        expect(jose.reload).not_to be_activated
      end

      scenario 'does not open an employee of another tenant' do
        visit employee_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating an employee' do
      let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS MECÂNICO') }
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, driver_code: 777, driver_document_digits: '52998224725')
      end

      scenario 'creates an employee linked to the Atua driver of the CPF' do
        visit employees_path
        click_on 'Novo Funcionário'

        fill_in 'Nome', with: 'Carlos Pereira'
        fill_in 'CPF', with: '529.982.247-25'
        select 'Masculino', from: 'Sexo'
        select 'MM Espinola', from: 'Empresa'
        fill_in 'Data de admissão', with: '2021-06-01'
        select 'CARLOS MECÂNICO', from: 'Funcionário da oficina'

        expect { click_on 'Cadastrar Funcionário' }.to change(Employee, :count).by(1).and change(Driver, :count).by(1)

        employee = Employee.last
        expect(page).to have_current_path(employee_path(employee))
        expect(page).to have_text('Funcionário cadastrado com sucesso.')
        expect(employee).to have_attributes(
          tenant:, name: 'CARLOS PEREIRA', legal_id: '52998224725', gender_type: 'male', company_type: 'mm_espinola',
          admitted_on: Date.new(2021, 6, 1), work_schedule_type: 'five_two', workshop_employee: mechanic, driver_code: 777
        )
        expect(employee).to be_activated
      end

      scenario 'shows the error of an invalid CPF' do
        visit new_employee_path

        fill_in 'Nome', with: 'Carlos Pereira'
        fill_in 'CPF', with: '529.982.247-00'
        select 'Masculino', from: 'Sexo'
        select 'TransJR', from: 'Empresa'

        expect { click_on 'Cadastrar Funcionário' }.not_to change(Employee, :count)

        expect(page).to have_text('CPF não é válido')
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', role: 'MOTORISTA') }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'keeps only the essential columns' do
      visit employees_path

      expect(page).to have_css('td', text: 'JOSE SILVA')
      expect(page).to have_no_css('td', text: 'MOTORISTA')
      expect(page).to have_no_css('td', text: 'TransJR')
    end
  end

  context 'when a user with read access to the employees is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:access, user: operator, resource: hr_resource, creates: false)
      create(:access, user: operator, resource:, creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'sees the listing without the create button and cannot create an employee' do
      visit employees_path

      expect(page).to have_css('h1.page-title', text: 'Funcionários')
      expect(page).to have_no_link('Novo Funcionário')

      expect do
        page.driver.submit :post, employees_path, { employee: { name: 'CARLOS', legal_id: '52998224725' } }
      end.not_to change(Employee, :count)
    end
  end
end
