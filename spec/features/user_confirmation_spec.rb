require 'rails_helper'

describe 'User account confirmation' do
  let!(:tenant) { create(:tenant) }

  context 'when an admin creates a user', :inline_jobs do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'the new user confirms the account through the e-mail link and defines the password' do
      visit new_user_path
      fill_in 'Nome', with: 'Eduardo Motorista'
      fill_in 'E-mail', with: 'eduardo@transjrbi.com.br'
      select 'Operador', from: 'Perfil'

      expect { click_on 'Cadastrar Usuário' }.to change { ActionMailer::Base.deliveries.count }.by(1)

      logout(:user)
      mail = ActionMailer::Base.deliveries.last
      link = Capybara.string(mail.body.encoded).find_link('Confirmar conta e definir senha')[:href]
      visit link

      expect(page).to have_text('Confirme sua conta')

      fill_in 'Senha', with: 'NovaSenha1!'
      fill_in 'Confirme a senha', with: 'NovaSenha1!'
      click_on 'Confirmar conta'

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Conta confirmada com sucesso. Bem-vindo ao TransJRBI!')

      user = User.find_by(email: 'eduardo@transjrbi.com.br')
      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
      expect(user.valid_password?('NovaSenha1!')).to be(true)
    end
  end

  context 'with an account waiting for confirmation' do
    let!(:user) { create(:user, tenant:, email: 'eduardo@transjrbi.com.br', confirmed_at: nil) }

    scenario 'cannot sign in before confirming the account' do
      visit new_user_session_path
      fill_in 'E-mail', with: 'eduardo@transjrbi.com.br'
      fill_in 'Senha', with: 'Senha123!'
      click_on 'Entrar'

      expect(page).to have_current_path(new_user_session_path)
      expect(user.reload.confirmed_at).to be_nil
    end

    scenario 'renders the confirmation screen in the login layout' do
      visit user_confirmation_path(confirmation_token: user.confirmation_token)

      expect(page).to have_css('.auth-hero', text: 'Sua operação com mais inteligência.')
      expect(page).to have_css('.auth-sheet', text: 'Confirme sua conta')
      expect(page).to have_no_css('.sidebar')
    end

    context 'when another user is signed in on the same browser' do
      let!(:admin) { create(:user, tenant:, user_type: :admin) }

      before { login_as(admin, scope: :user) }

      scenario 'keeps the confirmation screen in the login layout' do
        visit user_confirmation_path(confirmation_token: user.confirmation_token)

        expect(page).to have_css('.auth-sheet', text: 'Confirme sua conta')
        expect(page).to have_no_css('.sidebar')
      end
    end

    scenario 'shows the errors when the passwords do not match' do
      visit user_confirmation_path(confirmation_token: user.confirmation_token)
      fill_in 'Senha', with: 'NovaSenha1!'
      fill_in 'Confirme a senha', with: 'Diferente1!'
      click_on 'Confirmar conta'

      expect(page.status_code).to eq(422)
      expect(page).to have_text('Confirme a senha não é igual a Senha')
      expect(user.reload.confirmed_at).to be_nil
    end

    scenario 'shows the errors when the password is too short' do
      visit user_confirmation_path(confirmation_token: user.confirmation_token)
      fill_in 'Senha', with: 'abc'
      fill_in 'Confirme a senha', with: 'abc'
      click_on 'Confirmar conta'

      expect(page).to have_text('Senha é muito curto (mínimo: 8 caracteres)')
      expect(user.reload.confirmed_at).to be_nil
    end

    scenario 'does not show the password form when the link expired' do
      travel_to(4.days.from_now) do
        visit user_confirmation_path(confirmation_token: user.confirmation_token)

        expect(page).to have_text('Reenviar instruções de confirmação')
        expect(page).to have_no_field('Confirme a senha')
        expect(user.reload.confirmed_at).to be_nil
      end
    end

    scenario 'cannot reuse the link after confirming the account' do
      token = user.confirmation_token
      visit user_confirmation_path(confirmation_token: token)
      fill_in 'Senha', with: 'NovaSenha1!'
      fill_in 'Confirme a senha', with: 'NovaSenha1!'
      click_on 'Confirmar conta'
      logout(:user)

      expect(user.reload.confirmation_token).to be_nil

      visit user_confirmation_path(confirmation_token: token)

      expect(page).to have_text('Reenviar instruções de confirmação')
      expect(page).to have_no_field('Confirme a senha')
    end

    scenario 'does not confirm the account through a forged token' do
      page.driver.submit :put, user_confirmation_path,
                         { user_confirmation: { confirmation_token: 'forged', password: 'NovaSenha1!',
                                                password_confirmation: 'NovaSenha1!' } }

      expect(page.status_code).to eq(422)
      expect(page).to have_text('O link de confirmação é inválido ou expirou. Solicite um novo link.')
      expect(user.reload.confirmed_at).to be_nil
    end
  end
end
