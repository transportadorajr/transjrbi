require 'rails_helper'

describe 'Admin authentication', :admin do
  let!(:admin_user) { create(:admin_user, name: 'Marina Suporte', email: 'marina@transjrbi.com.br') }

  context 'without a session' do
    scenario 'redirects to the admin login screen' do
      visit admin_imports_path

      expect(page).to have_current_path(admin_login_path)
      expect(page).to have_text('Faça login para acessar o painel administrativo.')
    end

    scenario 'shows the JR visual identity on the login screen' do
      visit admin_login_path

      expect(page).to have_css('.auth-hero img[alt="Transportadora JR"][src*="brand/hero"]')
    end

    scenario 'shows the JR logo in the sidebar after signing in' do
      sign_in_admin(admin_user)

      expect(page).to have_css('#sidebar .sidebar-logo img[alt="Transportadora JR"][src*="brand/mark-light"]')
      expect(page).to have_css('#sidebar .sidebar-logo-label', text: 'Admin')
    end

    scenario 'signs in with the right password' do
      expect { sign_in_admin(admin_user) }.to change(Admin::Session, :count).by(1)

      expect(page).to have_current_path(admin_root_path)
      expect(page).to have_text('Login realizado com sucesso.')
      expect(page).to have_text('Marina Suporte')
      expect(Admin::Session.last.user).to eq(admin_user)
    end

    scenario 'refuses a wrong password' do
      expect { sign_in_admin(admin_user, password: 'errada') }.not_to change(Admin::Session, :count)

      expect(page).to have_text('E-mail ou senha inválidos.')
    end
  end

  context 'with an app user' do
    let!(:user) { create(:user, email: 'joao@transjrbi.com.br') }

    scenario 'does not accept the app credentials' do
      visit admin_login_path
      fill_in 'E-mail', with: user.email
      fill_in 'Senha', with: 'Senha123!'
      click_on 'Entrar'

      expect(page).to have_text('E-mail ou senha inválidos.')
      expect(Admin::Session.count).to eq(0)
    end
  end

  context 'with a signed in admin user' do
    before { sign_in_admin(admin_user) }

    scenario 'expires the session after 30 minutes without activity' do
      travel(31.minutes) { visit admin_imports_path }

      expect(page).to have_current_path(admin_login_path)
      expect(page).to have_text('Sua sessão expirou por inatividade. Faça login novamente.')
      expect(Admin::Session.count).to eq(0)
    end

    scenario 'signs out' do
      expect { page.driver.submit :delete, admin_session_path, {} }.to change(Admin::Session, :count).by(-1)

      expect(page).to have_current_path(admin_login_path)
      expect(page).to have_text('Você saiu do painel administrativo.')
    end
  end
end
