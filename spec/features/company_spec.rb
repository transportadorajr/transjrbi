require 'rails_helper'

describe 'Company' do
  let!(:tenant) do
    create(:tenant, name: 'Transportadora Teste Ltda', trade_name: 'Teste', legal_id: '11.111.111/0001-11',
                    atua_url: 'https://teste.atua.com.br', atua_device_token: 'token-antigo', atua_device_hash: nil)
  end
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra', legal_id: '22.222.222/0001-22') }
  let!(:resource) { create(:resource, name: 'Dados da empresa', slug: 'company') }

  context 'without a signed in user' do
    scenario 'redirects the screen to the login screen' do
      visit company_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not change the company' do
      page.driver.submit :patch, company_path, { company: { name: 'Invasor Ltda' } }

      expect(page).to have_current_path(new_user_session_path)
      expect(tenant.reload.name).to eq('Transportadora Teste Ltda')
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'shows the data of the tenant from the menu without revealing the secrets' do
      visit root_path
      within('.sidebar-desktop') { click_on 'Empresa' }

      expect(page).to have_current_path(company_path)
      expect(dl_to_hash('#company_data')).to eq(
        'Razão social' => tenant.name,
        'Nome fantasia' => tenant.trade_name,
        'CNPJ' => tenant.legal_id,
      )
      expect(dl_to_hash('#atua_data')).to eq(
        'URL da Atua' => tenant.atua_url,
        'Token do dispositivo na Atua' => 'Configurado',
        'Hash do dispositivo na Atua' => 'Não configurado',
      )
      expect(page).to have_no_text('token-antigo')
      expect(page).to have_no_text('Outra Transportadora Ltda')
    end

    scenario 'updates the company data and the Atua access' do
      visit company_path
      click_on 'Alterar'

      expect(page).to have_current_path(edit_company_path)
      expect(page).to have_field('Razão social', with: 'Transportadora Teste Ltda')
      expect(find_field('Token do dispositivo na Atua').value).to be_blank

      fill_in 'Razão social', with: ' Transportadora JR  Ltda '
      fill_in 'Nome fantasia', with: 'TransJR'
      fill_in 'CNPJ', with: '33.333.333/0001-33'
      fill_in 'URL da Atua', with: 'https://transjr.atua.com.br/'
      fill_in 'Hash do dispositivo na Atua', with: 'hash-de-producao'

      expect { click_on 'Salvar Alterações' }.not_to change(Tenant, :count)

      expect(page).to have_current_path(company_path)
      expect(page).to have_text('Dados da empresa atualizados com sucesso.')
      expect(page).to have_css('#current-tenant-name', text: 'TransJR')

      tenant.reload
      expect(tenant.name).to eq('Transportadora JR Ltda')
      expect(tenant.trade_name).to eq('TransJR')
      expect(tenant.legal_id).to eq('33.333.333/0001-33')
      expect(tenant.atua_url).to eq('https://transjr.atua.com.br')
      expect(tenant.atua_device_token).to eq('token-antigo')
      expect(tenant.atua_device_hash).to eq('hash-de-producao')
      expect(other_tenant.reload.name).to eq('Outra Transportadora Ltda')
    end

    scenario 'shows the errors when the data is invalid' do
      visit edit_company_path
      fill_in 'Razão social', with: ''
      fill_in 'CNPJ', with: other_tenant.legal_id
      fill_in 'URL da Atua', with: 'atua'
      click_on 'Salvar Alterações'

      expect(page).to have_text('Razão social não pode ficar em branco')
      expect(page).to have_text('CNPJ já está em uso')
      expect(page).to have_text('URL da Atua não é válido')
      expect(tenant.reload.name).to eq('Transportadora Teste Ltda')
      expect(tenant.legal_id).to eq('11.111.111/0001-11')
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'without access to the company' do
      scenario 'is sent back with an access denied message' do
        visit company_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the company' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'shows the data without the edit button' do
        visit company_path

        expect(dl_to_hash('#company_data')).to eq(
          'Razão social' => tenant.name,
          'Nome fantasia' => tenant.trade_name,
          'CNPJ' => tenant.legal_id,
        )
        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change the company through a forged request' do
        page.driver.submit :patch, company_path, { company: { name: 'Invasor Ltda' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(tenant.reload.name).to eq('Transportadora Teste Ltda')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'stacks the fields without scrolling horizontally' do
      visit edit_company_path
      use_mobile_screen

      expect(page).to have_field('Razão social')
      expect(page).to have_button('Salvar Alterações')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'masks the legal id as a CPF or a CNPJ while typing' do
      visit edit_company_path
      fill_in 'CNPJ', with: '12345678901'

      expect(page).to have_field('CNPJ', with: '123.456.789-01')

      fill_in 'CNPJ', with: '33444555000166'

      expect(page).to have_field('CNPJ', with: '33.444.555/0001-66')

      expect { click_on 'Salvar Alterações' }.not_to change(Tenant, :count)

      expect(page).to have_text('Dados da empresa atualizados com sucesso.')
      expect(tenant.reload.legal_id).to eq('33.444.555/0001-66')
    end
  end
end
