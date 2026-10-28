require 'rails_helper'

describe 'User sign in' do
  let!(:user) { create(:user, email: 'bruna@transjrbi.com.br') }

  def sign_in_with(email:, remember_me:)
    visit new_user_session_path
    fill_in 'E-mail', with: email
    fill_in 'Senha', with: 'Senha123!'
    remember_me ? check('Lembre-se de mim') : uncheck('Lembre-se de mim')
    click_on 'Entrar'
  end

  def sign_out
    page.driver.submit :delete, destroy_user_session_path, {}
  end

  context 'when the user signs in with remember me' do
    before do
      sign_in_with(email: 'bruna@transjrbi.com.br', remember_me: true)
      sign_out
    end

    scenario 'fills the e-mail and keeps remember me on after signing out' do
      visit new_user_session_path

      expect(page).to have_field('E-mail', with: 'bruna@transjrbi.com.br')
      expect(page).to have_checked_field('Lembre-se de mim')
    end

    scenario 'forgets the e-mail when the user signs in again without remember me' do
      sign_in_with(email: 'bruna@transjrbi.com.br', remember_me: false)
      sign_out

      visit new_user_session_path

      expect(page).to have_field('E-mail', with: '')
      expect(page).to have_unchecked_field('Lembre-se de mim')
    end

    scenario 'keeps the remembered e-mail when the sign in fails' do
      sign_in_with(email: 'outro@transjrbi.com.br', remember_me: false)

      visit new_user_session_path

      expect(page).to have_field('E-mail', with: 'bruna@transjrbi.com.br')
    end
  end

  context 'when the user signs in without remember me' do
    before do
      sign_in_with(email: 'bruna@transjrbi.com.br', remember_me: false)
      sign_out
    end

    scenario 'shows the login form empty after signing out' do
      visit new_user_session_path

      expect(page).to have_field('E-mail', with: '')
      expect(page).to have_unchecked_field('Lembre-se de mim')
    end
  end
end
