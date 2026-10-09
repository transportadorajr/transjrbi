require 'rails_helper'

describe 'GoodJob dashboard' do
  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit '/good_job'

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'with a signed in user' do
    let!(:user) { create(:user) }

    before { login_as(user, scope: :user) }

    scenario 'opens the dashboard' do
      visit '/good_job'

      expect(page.status_code).to eq(200)
      expect(page).to have_current_path(%r{\A/good_job})
    end
  end
end
