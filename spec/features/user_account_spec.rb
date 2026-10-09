require 'rails_helper'

describe 'User account' do
  context 'with a signed in user' do
    let!(:user) { create(:user, email: 'bruna@transjrbi.com.br') }

    before { login_as(user, scope: :user) }

    scenario 'does not offer the screen to edit the own account in the options menu' do
      visit root_path

      expect(page).to have_css('.navbar-dropdown-header', text: 'bruna@transjrbi.com.br', visible: :all)
      expect(page).to have_no_link('Minha conta', visible: :all)
    end

    scenario 'cannot update the own account through the former devise route' do
      page.driver.submit :put, '/users', { user: { email: 'outro@transjrbi.com.br', current_password: 'Senha123!' } }

      expect(page.status_code).to eq(404)
      expect(user.reload.email).to eq('bruna@transjrbi.com.br')
    end
  end
end
