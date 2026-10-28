require 'rails_helper'

describe 'Users' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit users_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) do
      create(:user, tenant:, name: 'Bruna Admin', email: 'bruna@transjrbi.com.br', phone: '(31) 99876-5432',
                    user_type: :admin, activated_at: Time.zone.local(2026, 10, 1, 9, 30))
    end
    let!(:owner) { create(:user, tenant:, name: 'Arthur Dono', email: 'arthur@transjrbi.com.br', user_type: :owner) }
    let!(:inactive_operator) do
      create(:user, tenant:, name: 'Carla Operadora', email: 'carla@transjrbi.com.br', activated_at: nil)
    end
    let!(:stranger) { create(:user, tenant: other_tenant, name: 'Diego Externo', email: 'diego@outra.com.br') }

    before { login_as(admin, scope: :user) }

    scenario 'lists only the users of the tenant with counters' do
      visit root_path
      within('.sidebar-desktop') { click_on 'Usuários' }

      expect(page).to have_current_path(users_path)
      expect(User.count).to eq(4)
      expect(tenant.users.count).to eq(3)
      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Telefone', 'Perfil', 'Status', 'Ações'],
          ['A Arthur Dono arthur@transjrbi.com.br', '-', 'Proprietário', 'Ativo', 'Opções Visualizar Alterar'],
          ['B Bruna Admin bruna@transjrbi.com.br', '(31) 99876-5432', 'Administrador', 'Ativo', 'Opções Visualizar Alterar'],
          ['C Carla Operadora carla@transjrbi.com.br', '-', 'Operador', 'Inativo', 'Opções Visualizar Alterar Ativar'],
        ],
      )
      expect(page).to have_no_text('Diego Externo')
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 3', 'Ativos 2', 'Inativos 1'])
      expect(page).to have_text('3 registros')
      expect(page).to have_link('Novo Usuário', href: new_user_path)
    end

    scenario 'filters the users by name and status' do
      visit users_path
      fill_in 'Nome do usuário', with: 'carla'
      select 'Inativo', from: 'Status'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Telefone', 'Perfil', 'Status', 'Ações'],
          ['C Carla Operadora carla@transjrbi.com.br', '-', 'Operador', 'Inativo', 'Opções Visualizar Alterar Ativar'],
        ],
      )
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 1', 'Ativos 0', 'Inativos 1'])
    end

    scenario 'shows the empty state when no user matches the filters' do
      visit users_path(name: 'ninguém')

      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_table
    end

    scenario 'shows the details of a user' do
      visit users_path
      within("#user_#{admin.id}") { first(:link, 'Visualizar').click }

      expect(page).to have_current_path(user_path(admin))
      expect(dl_to_hash).to eq(
        'Nome' => admin.name,
        'E-mail' => admin.email,
        'Telefone' => admin.phone,
        'Perfil' => 'Administrador',
        'Status' => 'Ativo',
        'Ativado em' => '01 de outubro, 09:30',
      )
    end

    scenario 'cannot see a user of another tenant' do
      visit user_path(stranger)

      expect(page.status_code).to eq(404)
    end

    context 'when deactivating a user' do
      let!(:active_operator) { create(:user, tenant:, name: 'Eduardo Operador', email: 'eduardo@transjrbi.com.br') }

      scenario 'deactivates the user without removing it' do
        visit users_path

        expect do
          page.driver.submit :delete, user_path(active_operator), {}
        end.not_to change(User, :count)

        expect(page).to have_current_path(users_path)
        expect(page).to have_text('Usuário inativado com sucesso.')
        expect(active_operator.reload.activated_at).to be_nil
        expect(active_operator).not_to be_activated
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 4', 'Ativos 2', 'Inativos 2'])
      end

      scenario 'keeps the filters of the listing after deactivating the user' do
        page.driver.submit :delete, user_path(active_operator, name: 'eduardo', status: 'active'), {}

        expect(page).to have_current_path(users_path(name: 'eduardo', status: 'active'))
        expect(page).to have_text('Usuário inativado com sucesso.')
        expect(page).to have_text('Nenhum registro encontrado')
      end

      scenario 'reactivates a deactivated user' do
        page.driver.submit :patch, activate_user_path(inactive_operator), {}

        expect(page).to have_current_path(users_path)
        expect(page).to have_text('Usuário reativado com sucesso.')
        expect(inactive_operator.reload.activated_at).to be_present
        expect(inactive_operator).to be_activated
      end

      scenario 'lists the deactivate option only for the users that can be deactivated' do
        visit users_path

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Telefone', 'Perfil', 'Status', 'Ações'],
            ['A Arthur Dono arthur@transjrbi.com.br', '-', 'Proprietário', 'Ativo', 'Opções Visualizar Alterar'],
            ['B Bruna Admin bruna@transjrbi.com.br', '(31) 99876-5432', 'Administrador', 'Ativo', 'Opções Visualizar Alterar'],
            ['C Carla Operadora carla@transjrbi.com.br', '-', 'Operador', 'Inativo', 'Opções Visualizar Alterar Ativar'],
            ['E Eduardo Operador eduardo@transjrbi.com.br', '-', 'Operador', 'Ativo', 'Opções Visualizar Alterar Inativar'],
          ],
        )
        expect(User.count).to eq(5)
        expect(page).to have_link('Inativar', href: user_path(active_operator))
        expect(page).to have_link('Ativar', href: activate_user_path(inactive_operator))
      end

      scenario 'cannot deactivate the owner of the company' do
        page.driver.submit :delete, user_path(owner), {}

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(owner.reload).to be_activated
      end

      scenario 'cannot deactivate its own account' do
        page.driver.submit :delete, user_path(admin), {}

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(admin.reload).to be_activated
      end

      scenario 'cannot deactivate a user of another tenant' do
        page.driver.submit :delete, user_path(stranger), {}

        expect(page.status_code).to eq(404)
        expect(stranger.reload).to be_activated
      end
    end

    context 'when creating a user' do
      scenario 'creates the user and sends the account confirmation e-mail', :inline_jobs do
        visit users_path
        click_on 'Novo Usuário'

        expect(page).to have_select('Perfil', options: %w[Selecione Administrador Operador])

        fill_in 'Nome', with: 'Eduardo Motorista'
        fill_in 'E-mail', with: 'Eduardo@TransJRBI.com.br'
        fill_in 'Telefone', with: '(31) 3333-4444'
        select 'Operador', from: 'Perfil'

        expect { click_on 'Cadastrar Usuário' }
          .to change(User, :count).by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)

        expect(page).to have_current_path(users_path)
        expect(page).to have_text('Usuário cadastrado com sucesso. Enviamos um e-mail para que ele confirme a conta e ' \
                                  'defina a senha de acesso.')

        user = User.last
        expect(user.tenant).to eq(tenant)
        expect(user.name).to eq('Eduardo Motorista')
        expect(user.email).to eq('eduardo@transjrbi.com.br')
        expect(user.phone).to eq('(31) 3333-4444')
        expect(user.user_type).to eq('operator')
        expect(user.activated_at).to be_present
        expect(user.confirmed_at).to be_nil

        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq(['eduardo@transjrbi.com.br'])
        expect(mail.subject).to eq('Confirme sua conta no TransJRBI')
      end

      scenario 'shows the errors of the required fields' do
        visit new_user_path

        expect { click_on 'Cadastrar Usuário' }.not_to change(User, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(page).to have_text('E-mail não pode ficar em branco')
        expect(page).to have_text('Perfil não pode ficar em branco')
        expect(enqueued_jobs).to be_empty
      end

      scenario 'does not accept an e-mail already in use' do
        visit new_user_path
        fill_in 'Nome', with: 'Outro Diego'
        fill_in 'E-mail', with: stranger.email
        select 'Administrador', from: 'Perfil'

        expect { click_on 'Cadastrar Usuário' }.not_to change(User, :count)

        expect(page).to have_text('E-mail já está em uso')
        expect(enqueued_jobs).to be_empty
      end
    end

    context 'when editing a user' do
      scenario 'updates the user without changing the e-mail' do
        visit user_path(inactive_operator)
        click_on 'Alterar'

        expect(page).to have_field('E-mail', with: 'carla@transjrbi.com.br', disabled: true)

        fill_in 'Nome', with: 'Carla Souza'
        fill_in 'Telefone', with: '31988887777'
        select 'Administrador', from: 'Perfil'

        expect { click_on 'Salvar Alterações' }.not_to change(User, :count)

        expect(page).to have_current_path(user_path(inactive_operator))
        expect(page).to have_text('Usuário atualizado com sucesso.')

        inactive_operator.reload
        expect(inactive_operator.name).to eq('Carla Souza')
        expect(inactive_operator.phone).to eq('31988887777')
        expect(inactive_operator.user_type).to eq('admin')
        expect(inactive_operator.email).to eq('carla@transjrbi.com.br')
      end

      scenario 'keeps the profile of the owner locked' do
        visit edit_user_path(owner)

        expect(page).to have_select('Perfil', selected: 'Proprietário', disabled: true)
      end

      scenario 'shows the errors when the name is removed' do
        visit edit_user_path(inactive_operator)
        fill_in 'Nome', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(inactive_operator.reload.name).to eq('Carla Operadora')
      end
    end
  end

  context 'when managing the permissions of a user' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }
    let!(:owner) { create(:user, tenant:, name: 'Arthur Dono', user_type: :owner) }
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora', email: 'carla@transjrbi.com.br') }
    let!(:freights) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }
    let!(:reports) { create(:resource, name: 'Relatórios', slug: 'reports', writable: false) }
    let!(:trips) { create(:resource, name: 'Viagens', slug: 'trips', writable: true) }

    before { login_as(admin, scope: :user) }

    scenario 'creates a user with its permissions', :inline_jobs do
      visit new_user_path

      expect(html_table_to_rows(table: find_by_id('user_permissions'))).to eq(
        [
          ['Recurso / Módulo', 'Apenas Leitura', 'Leitura e Edição'],
          ['Fretes Permite leitura e edição', '', ''],
          ['Relatórios Apenas leitura disponível', '', ''],
          ['Viagens Permite leitura e edição', '', ''],
        ],
      )
      expect(Resource.count).to eq(3)
      expect(page).to have_field("access_creates_#{reports.id}", disabled: true)

      fill_in 'Nome', with: 'Eduardo Motorista'
      fill_in 'E-mail', with: 'eduardo@transjrbi.com.br'
      select 'Operador', from: 'Perfil'
      check "access_creates_#{freights.id}"
      check "access_reads_#{reports.id}"

      expect { click_on 'Cadastrar Usuário' }
        .to change(User, :count).by(1)
        .and change(Access, :count).by(2)
        .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(page).to have_text('Usuário cadastrado com sucesso.')

      user = User.last
      expect(user.accesses.count).to eq(2)
      freights_access = user.accesses.find_by(resource: freights)
      expect(freights_access.tenant).to eq(tenant)
      expect(freights_access.reads).to be(true)
      expect(freights_access.creates).to be(true)
      reports_access = user.accesses.find_by(resource: reports)
      expect(reports_access.reads).to be(true)
      expect(reports_access.creates).to be(false)
    end

    context 'when the user already has permissions' do
      let!(:freights_access) { create(:access, user: operator, resource: freights, reads: true, creates: true) }
      let!(:reports_access) { create(:access, user: operator, resource: reports, reads: true, creates: false) }

      scenario 'shows the permissions of the user' do
        visit user_path(operator)

        expect(html_table_to_rows(table: find_by_id('user_permissions'))).to eq(
          [
            ['Recurso / Módulo', 'Apenas Leitura', 'Leitura e Edição'],
            %w[Fretes Sim Sim],
            %w[Relatórios Sim Não],
          ],
        )
        expect(operator.accesses.count).to eq(2)
      end

      scenario 'changes the permissions of the user' do
        visit edit_user_path(operator)

        expect(page).to have_checked_field("access_reads_#{freights.id}")
        expect(page).to have_checked_field("access_creates_#{freights.id}")
        expect(page).to have_checked_field("access_reads_#{reports.id}")
        expect(page).to have_unchecked_field("access_reads_#{trips.id}")

        uncheck "access_creates_#{freights.id}"
        uncheck "access_reads_#{reports.id}"
        check "access_reads_#{trips.id}"

        expect { click_on 'Salvar Alterações' }.not_to change(Access, :count)

        expect(page).to have_text('Usuário atualizado com sucesso.')
        expect(freights_access.reload.creates).to be(false)
        expect(freights_access.reads).to be(true)
        expect(Access.exists?(reports_access.id)).to be(false)
        expect(operator.accesses.find_by(resource: trips).reads).to be(true)
      end
    end

    scenario 'does not show the permissions of the owner' do
      visit user_path(owner)

      expect(page).to have_text('Arthur Dono')
      expect(page).to have_no_css('#user_permissions')
      expect(page).to have_no_text('Permissões de Acesso')

      visit edit_user_path(owner)

      expect(page).to have_select('Perfil', selected: 'Proprietário', disabled: true)
      expect(page).to have_no_css('#user_permissions')
    end
  end

  context 'when an operator with permissions edits its own account' do
    let!(:operator) { create(:user, tenant:, name: 'Fábio Operador') }
    let!(:freights) { create(:resource, name: 'Fretes', slug: 'freights') }
    let!(:freights_access) { create(:access, user: operator, resource: freights, reads: true, creates: false) }

    before { login_as(operator, scope: :user) }

    scenario 'does not see the permissions fields' do
      visit edit_user_path(operator)

      expect(page).to have_field('Nome', with: 'Fábio Operador')
      expect(page).to have_no_css('#user_permissions')
    end

    scenario 'cannot grant itself permissions through a forged request' do
      page.driver.submit :patch, user_path(operator), {
        user: { name: 'Fábio', access_attributes: { '0' => { resource_id: freights.id, reads: '1', creates: '1' } } },
      }

      expect(operator.accesses.count).to eq(1)
      expect(freights_access.reload.creates).to be(false)
    end
  end

  context 'when there are no resources to grant' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora', email: 'carla@transjrbi.com.br') }

    before { login_as(admin, scope: :user) }

    scenario 'shows the empty state in the permissions fields' do
      visit new_user_path

      expect(Resource.count).to eq(0)
      expect(page).to have_text('Permissões de Acesso')
      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_css('#user_permissions')
    end

    scenario 'shows the empty state in the permissions of a user without accesses' do
      visit user_path(operator)

      expect(operator.accesses.count).to eq(0)
      expect(page).to have_text('Permissões de Acesso')
      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_css('#user_permissions')
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Fábio Operador', email: 'fabio@transjrbi.com.br') }
    let!(:teammate) { create(:user, tenant:, name: 'Gabriela Admin', email: 'gabriela@transjrbi.com.br', user_type: :admin) }

    before { login_as(operator, scope: :user) }

    scenario 'sees only its own account and cannot create users' do
      visit users_path

      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Telefone', 'Perfil', 'Status', 'Ações'],
          ['F Fábio Operador fabio@transjrbi.com.br', '-', 'Operador', 'Ativo', 'Opções Visualizar Alterar'],
        ],
      )
      expect(page).to have_no_link('Novo Usuário')
    end

    scenario 'is denied when opening the new user screen' do
      visit new_user_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    scenario 'is denied when opening another user' do
      visit user_path(teammate)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    scenario 'edits its own account without changing its profile' do
      visit edit_user_path(operator)

      expect(page).to have_select('Perfil', selected: 'Operador', disabled: true)

      fill_in 'Nome', with: 'Fábio Lima'
      click_on 'Salvar Alterações'

      expect(page).to have_text('Usuário atualizado com sucesso.')
      expect(operator.reload.name).to eq('Fábio Lima')
      expect(operator.user_type).to eq('operator')
    end

    scenario 'cannot promote itself through a forged request' do
      page.driver.submit :patch, user_path(operator), { user: { name: 'Fábio', user_type: 'admin' } }

      expect(operator.reload.user_type).to eq('operator')
      expect(operator.name).to eq('Fábio')
    end

    scenario 'cannot deactivate another user through a forged request' do
      page.driver.submit :delete, user_path(teammate), {}

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(teammate.reload).to be_activated
    end
  end

  context 'when a deactivated user tries to sign in' do
    let!(:deactivated_user) { create(:user, tenant:, email: 'helena@transjrbi.com.br', activated_at: nil) }

    scenario 'is kept on the login screen with the deactivation message' do
      visit new_user_session_path
      fill_in 'E-mail', with: 'helena@transjrbi.com.br'
      fill_in 'Senha', with: 'Senha123!'
      click_on 'Entrar'

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_text('Seu usuário está inativo. Fale com o administrador da sua empresa.')
    end
  end

  context 'when a signed in user is deactivated' do
    let!(:user) { create(:user, tenant:, name: 'Igor Operador', email: 'igor@transjrbi.com.br') }

    before { login_as(user, scope: :user) }

    scenario 'loses the access on the next request' do
      user.update!(activated: false)

      visit users_path

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_text('Seu usuário está inativo. Fale com o administrador da sua empresa.')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', phone: '(31) 99876-5432', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit users_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'TELEFONE')
      expect(page).to have_no_css('th', text: 'PERFIL')

      within("#user_#{admin.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_user_path(admin))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    context 'when there is an operator to deactivate' do
      let!(:operator) { create(:user, tenant:, name: 'Júlia Operadora', email: 'julia@transjrbi.com.br') }

      scenario 'deactivates the user from the actions menu after confirming' do
        visit users_path
        use_mobile_screen

        within("#user_#{operator.id}") do
          click_button 'Opções'
          accept_confirm('Tem certeza que deseja inativar este usuário? Ele perderá o acesso ao sistema.') { click_on 'Inativar' }
        end

        expect(page).to have_text('Usuário inativado com sucesso.')
        within("#user_#{operator.id}") { expect(page).to have_text('Inativo') }
        expect(operator.reload).not_to be_activated
      end
    end

    context 'when there are resources to grant' do
      let!(:freights) { create(:resource, name: 'Fretes', slug: 'freights') }

      scenario 'fits the permissions table on the screen' do
        visit new_user_path
        use_mobile_screen

        expect(page).to have_css('#user_permissions th', text: 'LEITURA E EDIÇÃO')
        check "access_creates_#{freights.id}"

        expect(page).to have_checked_field("access_creates_#{freights.id}")
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end
end
