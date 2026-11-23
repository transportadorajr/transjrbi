require 'rails_helper'

describe 'Job positions', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Cargos', slug: 'job_positions') }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit job_positions_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the HR flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit job_positions_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no job positions' do
      scenario 'shows the empty listing' do
        visit job_positions_path

        expect(JobPosition.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are job positions' do
      let!(:truck_driver) { create(:job_position, tenant:, name: 'MOTORISTA') }
      let!(:assistant) { create(:job_position, tenant:, name: 'AUXILIAR', activated: false) }
      let!(:stranger) { create(:job_position, tenant: other_tenant, name: 'CARGO DE OUTRA') }

      before do
        create(:employee, tenant:, legal_id: '52998224725', job_position: truck_driver)
        create(:employee, tenant:, legal_id: '11144477735', job_position: truck_driver)
      end

      scenario 'lists the job positions from the HR menu' do
        visit employees_path
        within('.sidebar-desktop') { click_on 'Cargos' }

        expect(page).to have_current_path(job_positions_path)
        expect(JobPosition.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Funcionários', 'Situação', 'Ações'],
            ['AUXILIAR', '0', 'Inativo', 'Opções Alterar Ativar'],
            ['MOTORISTA', '2', 'Ativo', 'Opções Alterar Inativar'],
          ],
        )
        expect(page).to have_link('Novo Cargo', href: new_job_position_path)
        expect(page).to have_no_text('CARGO DE OUTRA')
      end

      scenario 'filters the job positions' do
        visit job_positions_path
        fill_in 'Nome', with: 'motor'
        select 'Ativo', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(JobPosition.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Funcionários', 'Situação', 'Ações'],
            ['MOTORISTA', '2', 'Ativo', 'Opções Alterar Inativar'],
          ],
        )
      end

      scenario 'edits a job position' do
        visit job_positions_path
        within("#job_position_#{truck_driver.id} .inline-actions") { click_on 'Alterar' }

        fill_in 'Nome', with: 'motorista carreteiro'

        expect { click_on 'Salvar Alterações' }.not_to change(JobPosition, :count)

        expect(page).to have_current_path(job_positions_path)
        expect(page).to have_text('Cargo atualizado com sucesso.')
        expect(truck_driver.reload.name).to eq('MOTORISTA CARRETEIRO')
        expect(truck_driver).to be_activated
      end

      scenario 'shows the error of a name already registered' do
        visit new_job_position_path
        fill_in 'Nome', with: 'Motorista'

        expect { click_on 'Cadastrar Cargo' }.not_to change(JobPosition, :count)

        expect(page).to have_text('Nome já está em uso')
      end

      scenario 'deactivates a job position from the listing' do
        visit job_positions_path

        expect { page.driver.submit :patch, deactivate_job_position_path(truck_driver), {} }
          .not_to change(JobPosition, :count)

        expect(page).to have_text('Registro inativado com sucesso.')
        expect(truck_driver.reload).not_to be_activated
      end

      scenario 'does not edit a job position of another tenant' do
        visit edit_job_position_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    scenario 'creates a job position' do
      visit job_positions_path
      click_on 'Novo Cargo'

      fill_in 'Nome', with: ' mecânico  '

      expect { click_on 'Cadastrar Cargo' }.to change(JobPosition, :count).by(1)

      job_position = JobPosition.last
      expect(page).to have_current_path(job_positions_path)
      expect(page).to have_text('Cargo cadastrado com sucesso.')
      expect(job_position).to have_attributes(tenant:, name: 'MECÂNICO')
      expect(job_position).to be_activated
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:job_position, tenant:, name: 'MOTORISTA')
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'keeps only the essential columns' do
      visit job_positions_path

      expect(page).to have_css('td', text: 'MOTORISTA')
      expect(page).to have_no_css('th', text: 'Funcionários')
    end
  end

  context 'when a user with read access to the job positions is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:access, user: operator, resource: hr_resource, creates: false)
      create(:access, user: operator, resource:, creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'sees the listing without the create button and cannot create a job position' do
      visit job_positions_path

      expect(page).to have_css('h1.page-title', text: 'Cargos')
      expect(page).to have_no_link('Novo Cargo')

      expect do
        page.driver.submit :post, job_positions_path, { job_position: { name: 'MOTORISTA' } }
      end.not_to change(JobPosition, :count)
    end
  end
end
