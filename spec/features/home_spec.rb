require 'rails_helper'

describe 'Home' do
  context 'when an operator without access to the freight billing is signed in' do
    let!(:user) { create(:user, name: 'Bruna Costa', email: 'bruna@transjrbi.com.br') }

    before { login_as(user, scope: :user) }

    scenario 'welcomes the user to JR BI' do
      visit root_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_title('Início')
      expect(page).to have_css('.page-header h1.page-title', text: 'Bem-vindo ao JR BI, Bruna Costa!')
      expect(page).to have_text('A inteligência do seu negócio em um só lugar.')
      expect(page).to have_css('h2', text: 'Decisões guiadas por dados')
      expect(page).to have_no_button('Cumprimentar')
    end

    scenario 'welcomes the user on a phone screen', :js do
      use_mobile_screen

      visit root_path

      expect(page).to have_css('.page-header h1.page-title', text: 'Bem-vindo ao JR BI, Bruna Costa!')
      expect(page).to have_css('h2', text: 'Decisões guiadas por dados')
    end
  end
end
