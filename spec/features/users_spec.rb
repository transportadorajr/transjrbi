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
          ['C Carla Operadora carla@transjrbi.com.br', '-', 'Operador', 'Inativo', 'Opções Visualizar Alterar'],
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
          ['C Carla Operadora carla@transjrbi.com.br', '-', 'Operador', 'Inativo', 'Opções Visualizar Alterar'],
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
  end
end
