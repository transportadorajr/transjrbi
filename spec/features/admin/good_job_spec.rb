require 'rails_helper'

describe 'Admin GoodJob dashboard', :admin do
  let!(:admin_user) { create(:admin_user) }

  context 'without a session' do
    scenario 'redirects to the admin login screen' do
      visit '/good_job'

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with a signed in admin user' do
    before { sign_in_admin(admin_user) }

    scenario 'opens the dashboard from the sidebar menu' do
      within('#sidebar') { click_on 'Jobs (GoodJob)' }

      expect(page.status_code).to eq(200)
      expect(page).to have_current_path(%r{\A/good_job})
    end

    scenario 'redirects to the login screen once the session expires' do
      travel(31.minutes) { visit '/good_job' }

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with an app user signed in' do
    let!(:user) { create(:user) }

    before { sign_in user }

    scenario 'does not reach the dashboard' do
      visit '/good_job'

      expect(page).to have_current_path(admin_login_path)
    end
  end
end
