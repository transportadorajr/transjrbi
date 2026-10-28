require 'rails_helper'

describe 'User password change' do
  let!(:tenant) { create(:tenant) }

  def sign_in_with(email:, password: 'Senha123!')
    visit new_user_session_path
    fill_in 'E-mail', with: email
    fill_in 'Senha', with: password
    click_on 'Entrar'
  end

  context 'with a user required to change the password defined by the owner' do
    let!(:user) { create(:user, tenant:, email: 'eduardo@transjrbi.com.br', password_change_required: true) }

    scenario 'asks for the new password right after signing in' do
      sign_in_with(email: 'eduardo@transjrbi.com.br')

      expect(page).to have_current_path(edit_password_change_path)
      expect(page).to have_css('.auth-title', text: 'Defina sua nova senha')
      expect(page).to have_text('Sua senha foi definida pelo administrador.')
      expect(page).to have_no_css('.sidebar')
    end

    scenario 'does not let the user reach any other screen before changing the password' do
      login_as(user, scope: :user)

      visit users_path

      expect(page).to have_current_path(edit_password_change_path)
    end

    scenario 'redirects a form submission to the password change screen' do
      login_as(user, scope: :user)
      visit edit_password_change_path

      page.driver.submit :patch, user_path(user), { user: { name: 'Outro Nome' } }

      expect(page).to have_current_path(edit_password_change_path)
      expect(user.reload.name).to eq('João Silva')
    end

    scenario 'changes the password and keeps the user signed in', :inline_jobs do
      sign_in_with(email: 'eduardo@transjrbi.com.br')
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'NovaSenha1!'

      expect { click_on 'Alterar senha' }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Senha alterada com sucesso.')

      user.reload
      expect(user.valid_password?('NovaSenha1!')).to be(true)
      expect(user.password_change_required?).to be(false)

      visit users_path

      expect(page).to have_current_path(users_path)
    end

    scenario 'rejects the password defined by the owner' do
      sign_in_with(email: 'eduardo@transjrbi.com.br')
      fill_in 'Nova senha', with: 'Senha123!'
      fill_in 'Confirme a nova senha', with: 'Senha123!'
      click_on 'Alterar senha'

      expect(page).to have_text('Nova senha deve ser diferente da senha atual')
      expect(user.reload.password_change_required?).to be(true)
    end

    scenario 'rejects a confirmation that does not match the new password' do
      sign_in_with(email: 'eduardo@transjrbi.com.br')
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'Outra123!'
      click_on 'Alterar senha'

      expect(page).to have_text('Confirme a nova senha não é igual a Nova senha')
      expect(user.reload.valid_password?('Senha123!')).to be(true)
    end

    scenario 'rejects a password that is too short' do
      sign_in_with(email: 'eduardo@transjrbi.com.br')
      fill_in 'Nova senha', with: '123'
      fill_in 'Confirme a nova senha', with: '123'
      click_on 'Alterar senha'

      expect(page).to have_text('Nova senha é muito curto')
      expect(user.reload.password_change_required?).to be(true)
    end

    scenario 'signs out from the password change screen' do
      sign_in_with(email: 'eduardo@transjrbi.com.br')
      page.driver.submit :delete, destroy_user_session_path, {}

      visit users_path

      expect(page).to have_current_path(new_user_session_path)
      expect(user.reload.password_change_required?).to be(true)
    end

    scenario 'changes the password on a phone', :js do
      use_mobile_screen
      sign_in_with(email: 'eduardo@transjrbi.com.br')

      expect(page).to have_css('.auth-title', text: 'Defina sua nova senha')
      expect(page).to have_link('Sair')

      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'NovaSenha1!'
      click_on 'Alterar senha'

      expect(page).to have_text('Senha alterada com sucesso.')
      expect(user.reload.password_change_required?).to be(false)
    end
  end

  context 'with a user not required to change the password' do
    let!(:user) { create(:user, tenant:, email: 'eduardo@transjrbi.com.br') }

    before { login_as(user, scope: :user) }

    scenario 'does not show the password change screen' do
      visit edit_password_change_path

      expect(page).to have_current_path(root_path)
    end

    scenario 'cannot change the password through the password change route' do
      page.driver.submit :patch, password_change_path,
                         { password_change: { password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!' } }

      expect(page).to have_current_path(root_path)
      expect(user.reload.valid_password?('Senha123!')).to be(true)
    end
  end
end
