require 'rails_helper'

describe 'User password reset' do
  let!(:tenant) { create(:tenant) }

  context 'with a confirmed user' do
    let!(:user) { create(:user, tenant:, email: 'eduardo@transjrbi.com.br') }

    scenario 'renders the request screen in the login layout' do
      visit new_user_session_path
      click_on 'Esqueci minha senha'

      expect(page).to have_current_path(new_user_password_path)
      expect(page).to have_css('.auth-hero', text: 'Sua operação com mais inteligência.')
      expect(page).to have_no_css('.sidebar')
    end

    scenario 'requests the instructions and defines a new password', :inline_jobs do
      visit new_user_password_path
      fill_in 'E-mail', with: 'eduardo@transjrbi.com.br'

      expect { click_on 'Enviar instruções para redefinição da senha' }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      link = Capybara.string(mail.body.encoded).first(:link)[:href]
      visit link

      expect(page).to have_css('.auth-hero')
      expect(page).to have_no_css('.sidebar')

      fill_in 'Nova senha', with: 'NovaSenha1!'
      fill_in 'Confirme sua nova senha', with: 'NovaSenha1!'
      click_on 'Alterar minha senha'

      expect(user.reload.valid_password?('NovaSenha1!')).to be(true)
    end
  end
end
