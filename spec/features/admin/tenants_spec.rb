require 'rails_helper'

describe 'Admin tenants', :admin do
  let!(:admin_user) { create(:admin_user) }

  context 'without a session' do
    scenario 'redirects to the admin login screen' do
      visit admin_tenants_path

      expect(page).to have_current_path(admin_login_path)
    end

    scenario 'does not create a tenant' do
      expect do
        page.driver.submit :post, admin_tenants_path, { admin_tenant: { name: 'Nova Ltda', trade_name: 'Nova',
                                                                        legal_id: '11.222.333/0001-44' } }
      end.not_to change(Tenant, :count)

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with an app owner signed in' do
    let!(:owner) { create(:user, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not reach the listing' do
      visit admin_tenants_path

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with a signed in admin user' do
    before { sign_in_admin(admin_user) }

    context 'when there are no tenants' do
      scenario 'shows the empty state message' do
        visit admin_tenants_path

        expect(Tenant.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are tenants' do
      let!(:transjr) do
        create(:tenant, name: 'Transportadora JR Ltda', trade_name: 'TransJR', legal_id: '12.345.678/0001-90')
      end
      let!(:rodoviario) do
        create(:tenant, name: 'Rodoviário Minas S.A.', trade_name: 'RodoMinas', legal_id: '98.765.432/0001-10')
      end
      let!(:transjr_owner) { create(:user, tenant: transjr, user_type: :owner, email: 'dono@transjr.com.br') }

      scenario 'lists every tenant with its owner' do
        within('#sidebar') { click_on 'Empresas' }

        expect(page).to have_current_path(admin_tenants_path)
        expect(Tenant.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome fantasia', 'Razão social', 'CNPJ', 'Usuário administrador', 'Ações'],
            ['RodoMinas', 'Rodoviário Minas S.A.', '98.765.432/0001-10', '-', ''],
            ['TransJR', 'Transportadora JR Ltda', '12.345.678/0001-90', 'dono@transjr.com.br', ''],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link('Nova Empresa', href: new_admin_tenant_path)
      end

      scenario 'filters the tenants by trade name' do
        visit admin_tenants_path
        fill_in 'Razão social ou nome fantasia', with: 'rodo'
        click_on 'Aplicar Filtros'

        expect(Tenant.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome fantasia', 'Razão social', 'CNPJ', 'Usuário administrador', 'Ações'],
            ['RodoMinas', 'Rodoviário Minas S.A.', '98.765.432/0001-10', '-', ''],
          ],
        )
      end
    end

    context 'when creating a tenant' do
      scenario 'creates the tenant with a confirmed owner who can sign in to the app' do
        visit admin_tenants_path
        click_on 'Nova Empresa'

        expect(page).to have_current_path(new_admin_tenant_path)

        fill_in 'Razão social', with: '  Nova Logística Ltda '
        fill_in 'Nome fantasia', with: 'Nova Log'
        fill_in 'CNPJ', with: '11.222.333/0001-44'
        fill_in 'URL da Atua', with: 'https://novalog.atua.com.br/'
        fill_in 'Nome do administrador', with: 'Carla Souza'
        fill_in 'E-mail do administrador', with: 'Carla@NovaLog.com.br'
        fill_in 'Senha do administrador', with: 'Senha123!'
        fill_in 'Confirme a senha do administrador', with: 'Senha123!'

        expect { click_on 'Cadastrar Empresa' }
          .to change(Tenant, :count).by(1)
          .and change(User, :count).by(1)
          .and not_change { ActionMailer::Base.deliveries.count }

        expect(page).to have_current_path(admin_tenants_path)
        expect(page).to have_text('Empresa cadastrada com sucesso. O usuário administrador já pode entrar no sistema.')

        tenant = Tenant.last
        expect(tenant.name).to eq('Nova Logística Ltda')
        expect(tenant.trade_name).to eq('Nova Log')
        expect(tenant.legal_id).to eq('11.222.333/0001-44')
        expect(tenant.atua_url).to eq('https://novalog.atua.com.br')

        owner = User.last
        expect(owner.tenant).to eq(tenant)
        expect(owner.name).to eq('Carla Souza')
        expect(owner.email).to eq('carla@novalog.com.br')
        expect(owner.user_type).to eq('owner')
        expect(owner.activated_at).to be_present
        expect(owner.confirmed_at).to be_present

        visit "http://#{Rails.application.config.x.app_host}#{new_user_session_path}"
        fill_in 'E-mail', with: 'carla@novalog.com.br'
        fill_in 'Senha', with: 'Senha123!'
        click_on 'Entrar'

        expect(page).to have_current_path(root_path)
        expect(owner.reload.sign_in_count).to eq(1)
      end

      scenario 'shows the errors of the required fields' do
        visit new_admin_tenant_path

        expect { click_on 'Cadastrar Empresa' }.not_to change(Tenant, :count)

        expect(page).to have_text('Razão social não pode ficar em branco')
        expect(page).to have_text('Nome fantasia não pode ficar em branco')
        expect(page).to have_text('CNPJ não pode ficar em branco')
        expect(page).to have_text('Nome do administrador não pode ficar em branco')
        expect(page).to have_text('E-mail do administrador não pode ficar em branco')
        expect(page).to have_text('Senha do administrador não pode ficar em branco')
        expect(User.count).to eq(0)
      end

      context 'when the owner e-mail is already in use' do
        let!(:existing_user) { create(:user, email: 'carla@novalog.com.br') }

        scenario 'keeps the tenant out and shows the validation message' do
          visit new_admin_tenant_path
          fill_in 'Razão social', with: 'Nova Logística Ltda'
          fill_in 'Nome fantasia', with: 'Nova Log'
          fill_in 'CNPJ', with: '11.222.333/0001-44'
          fill_in 'Nome do administrador', with: 'Carla Souza'
          fill_in 'E-mail do administrador', with: 'carla@novalog.com.br'
          fill_in 'Senha do administrador', with: 'Senha123!'
          fill_in 'Confirme a senha do administrador', with: 'Senha123!'

          expect { click_on 'Cadastrar Empresa' }
            .to not_change(Tenant, :count)
            .and not_change(User, :count)

          expect(page).to have_text('E-mail do administrador já está em uso')
        end
      end
    end

    context 'when editing a tenant' do
      let!(:tenant) do
        create(:tenant, name: 'Transportadora JR Ltda', trade_name: 'TransJR', legal_id: '12.345.678/0001-90')
      end
      let!(:owner) { create(:user, tenant:, user_type: :owner) }

      scenario 'updates the company data without the owner fields' do
        visit admin_tenants_path
        within("#tenant_#{tenant.id}") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_admin_tenant_path(tenant))
        expect(page).to have_field('CNPJ', with: '12.345.678/0001-90')
        expect(page).to have_no_field('Nome do administrador')
        expect(page).to have_no_field('Senha do administrador')

        fill_in 'Nome fantasia', with: 'TransJR Logística'

        expect { click_on 'Salvar Alterações' }.to not_change(Tenant, :count).and not_change(User, :count)

        expect(page).to have_current_path(admin_tenants_path)
        expect(page).to have_text('Empresa atualizada com sucesso.')

        tenant.reload
        expect(tenant.name).to eq('Transportadora JR Ltda')
        expect(tenant.trade_name).to eq('TransJR Logística')
        expect(tenant.legal_id).to eq('12.345.678/0001-90')
      end

      scenario 'shows the errors when the trade name is removed' do
        visit edit_admin_tenant_path(tenant)
        fill_in 'Nome fantasia', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome fantasia não pode ficar em branco')
        expect(tenant.reload.trade_name).to eq('TransJR')
      end
    end

    context 'when the tenant does not exist' do
      scenario 'renders the not found page' do
        visit edit_admin_tenant_path(id: 0)

        expect(page.status_code).to eq(404)
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:tenant) { create(:tenant, trade_name: 'TransJR') }

    before { sign_in_admin(admin_user) }

    scenario 'keeps the essential columns and the edit action' do
      visit admin_tenants_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME FANTASIA')
      expect(page).to have_no_css('th', text: 'CNPJ')

      within("#tenant_#{tenant.id}") { click_on 'Alterar' }

      expect(page).to have_current_path(edit_admin_tenant_path(tenant))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'creates a tenant with a CPF typed into the masked legal id' do
      visit new_admin_tenant_path
      use_mobile_screen

      fill_in 'Razão social', with: 'Carla Souza Transportes'
      fill_in 'Nome fantasia', with: 'Carla Transportes'
      fill_in 'CNPJ', with: '12345678901'

      expect(page).to have_field('CNPJ', with: '123.456.789-01')

      fill_in 'Nome do administrador', with: 'Carla Souza'
      fill_in 'E-mail do administrador', with: 'carla@carlatransportes.com.br'
      fill_in 'Senha do administrador', with: 'Senha123!'
      fill_in 'Confirme a senha do administrador', with: 'Senha123!'

      expect { click_on 'Cadastrar Empresa' }.to change(Tenant, :count).by(1).and change(User, :count).by(1)

      expect(page).to have_text('Empresa cadastrada com sucesso.')

      created_tenant = Tenant.last
      expect(created_tenant.legal_id).to eq('123.456.789-01')
      expect(created_tenant.trade_name).to eq('Carla Transportes')
      expect(created_tenant.owner.email).to eq('carla@carlatransportes.com.br')
    end
  end
end
