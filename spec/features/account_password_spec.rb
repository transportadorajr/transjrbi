require 'rails_helper'

describe 'Account password' do
  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit edit_account_password_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'with a signed in user' do
    let!(:tenant) { create(:tenant) }
    let!(:user) { create(:user, tenant:, name: 'Bruna Costa', email: 'bruna@transjrbi.com.br', user_type: 'admin') }
    let!(:other_user) { create(:user, tenant:, user_type: 'owner', name: 'Carlos Lima') }

    before { login_as(user, scope: :user) }

    scenario 'reaches the password change from the own user screen' do
      visit user_path(user)
      within('.page-actions') { click_on 'Alterar senha' }

      expect(page).to have_current_path(edit_account_password_path)
      expect(page).to have_css('.page-title', text: 'Alterar Senha')
    end

    scenario 'reaches the password change from the options menu' do
      visit root_path

      expect(page).to have_link('Alterar senha', href: edit_account_password_path, visible: :all)
    end

    scenario 'changes the own password and keeps the user signed in', :inline_jobs do
      visit edit_account_password_path
      fill_in 'Senha atual', with: 'Senha123!'
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'NovaSenha1!'

      expect { click_button 'Alterar senha' }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(page).to have_current_path(user_path(user))
      expect(page).to have_text('Senha alterada com sucesso.')
      expect(user.reload.valid_password?('NovaSenha1!')).to be(true)
      expect(other_user.reload.valid_password?('Senha123!')).to be(true)

      visit users_path

      expect(page).to have_current_path(users_path)
    end

    scenario 'rejects a wrong current password' do
      visit edit_account_password_path
      fill_in 'Senha atual', with: 'Errada123!'
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'NovaSenha1!'

      expect { click_button 'Alterar senha' }.not_to(change { ActionMailer::Base.deliveries.count })

      expect(page).to have_text('Senha atual está incorreta')
      expect(user.reload.valid_password?('Senha123!')).to be(true)
    end

    scenario 'rejects a confirmation that does not match the new password' do
      visit edit_account_password_path
      fill_in 'Senha atual', with: 'Senha123!'
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'Outra123!'
      click_button 'Alterar senha'

      expect(page).to have_text('Confirme a nova senha não é igual a Nova senha')
      expect(user.reload.valid_password?('Senha123!')).to be(true)
    end

    scenario 'does not offer the password change on the screen of another user' do
      visit user_path(other_user)

      expect(page).to have_css('.page-title', text: 'Carlos Lima')
      expect(page).to have_no_css('.page-actions a', text: 'Alterar senha')
    end

    scenario 'cannot change the password of another user through the form' do
      page.driver.submit :patch, account_password_path,
                         { user_id: other_user.id,
                           account_password: { current_password: 'Senha123!', password: 'NovaSenha1!',
                                               password_confirmation: 'NovaSenha1!' } }

      expect(user.reload.valid_password?('NovaSenha1!')).to be(true)
      expect(other_user.reload.valid_password?('Senha123!')).to be(true)
    end

    scenario 'changes the own password on a phone', :js do
      use_mobile_screen
      visit edit_account_password_path
      fill_in 'Senha atual', with: 'Senha123!'
      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme a nova senha', with: 'NovaSenha1!'
      click_button 'Alterar senha'

      expect(page).to have_text('Senha alterada com sucesso.')
      expect(user.reload.valid_password?('NovaSenha1!')).to be(true)
    end
  end
end
