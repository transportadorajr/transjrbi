require 'rails_helper'

describe 'Workshop employees' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Funcionários da oficina', slug: 'workshop_employees') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit workshop_employees_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit workshop_employees_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no employees' do
      scenario 'shows the empty state message' do
        visit workshop_employees_path

        expect(WorkshopEmployee.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are employees' do
      let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
      let!(:paulo) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
      let!(:andre) { create(:workshop_employee, tenant:, name: 'ANDRÉ ROCHA', active: false) }
      let!(:stranger) { create(:workshop_employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA') }

      scenario 'lists the employees from the maintenance menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Manutenção'
          click_on 'Funcionários da oficina'
        end

        expect(page).to have_current_path(workshop_employees_path)
        expect(WorkshopEmployee.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            %w[Nome Função Ativo Ações],
            ['ANDRÉ ROCHA', 'Mecânico', 'Inativo', ''],
            ['CARLOS SOUZA', 'Mecânico', 'Ativo', ''],
            ['PAULO LIMA', 'Encarregado', 'Ativo', ''],
          ],
        )
        expect(page).to have_link('Novo Funcionário', href: new_workshop_employee_path)
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'filters the employees by name and role' do
        visit workshop_employees_path
        fill_in 'Nome', with: 'lima'
        select 'Encarregado', from: 'Função'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            %w[Nome Função Ativo Ações],
            ['PAULO LIMA', 'Encarregado', 'Ativo', ''],
          ],
        )
      end

      scenario 'edits an employee' do
        visit workshop_employees_path
        within("#workshop_employee_#{carlos.id}") { click_on 'Alterar' }

        fill_in 'Nome', with: 'Carlos Souza Filho'
        select 'Encarregado', from: 'Função'
        uncheck 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(WorkshopEmployee, :count)

        expect(page).to have_current_path(workshop_employees_path)
        expect(page).to have_text('Funcionário atualizado com sucesso.')
        expect(carlos.reload).to have_attributes(name: 'CARLOS SOUZA FILHO', role_type: 'supervisor', active: false)
      end

      scenario 'does not edit an employee of another tenant' do
        visit edit_workshop_employee_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating an employee' do
      let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }

      scenario 'creates a supervisor' do
        visit workshop_employees_path
        click_on 'Novo Funcionário'

        fill_in 'Nome', with: 'Paulo Lima'
        select 'Encarregado', from: 'Função'

        expect { click_on 'Cadastrar Funcionário' }.to change(WorkshopEmployee, :count).by(1)

        expect(page).to have_current_path(workshop_employees_path)
        expect(page).to have_text('Funcionário cadastrado com sucesso.')
        expect(WorkshopEmployee.last).to have_attributes(tenant:, name: 'PAULO LIMA', role_type: 'supervisor', active: true)
      end

      scenario 'shows the error of a name already registered' do
        visit new_workshop_employee_path

        fill_in 'Nome', with: 'carlos souza'

        expect { click_on 'Cadastrar Funcionário' }.not_to change(WorkshopEmployee, :count)

        expect(page).to have_text('Nome já está cadastrado')
      end
    end
  end

  context 'when a user without access to the workshop employees is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }

    before { login_as(operator, scope: :user) }

    scenario 'cannot open the listing nor create an employee' do
      visit workshop_employees_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect do
        page.driver.submit :post, workshop_employees_path, { workshop_employee: { name: 'CARLOS' } }
      end.not_to change(WorkshopEmployee, :count)
    end
  end
end
