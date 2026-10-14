require 'rails_helper'

describe 'Admin feature flags', :admin do
  let!(:admin_user) { create(:admin_user) }

  context 'without a session' do
    scenario 'redirects to the admin login screen' do
      visit '/flipper'

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with a signed in admin user' do
    before do
      Flipper.add(:new_dashboard)
      sign_in_admin(admin_user)
    end

    scenario 'opens the Flipper UI from the sidebar menu' do
      within('#sidebar') { click_on 'Feature flags' }

      expect(page).to have_current_path('/flipper/features')
      expect(page).to have_text('new_dashboard')
    end

    scenario 'enables a feature flag' do
      visit '/flipper/features/new_dashboard'
      click_on 'Fully Enable'

      expect(Flipper.enabled?(:new_dashboard)).to be(true)
    end

    scenario 'redirects to the login screen once the session expires' do
      travel(31.minutes) { visit '/flipper' }

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with an app user signed in' do
    let!(:user) { create(:user) }

    before { sign_in user }

    scenario 'does not reach the Flipper UI' do
      visit '/flipper'

      expect(page).to have_current_path(admin_login_path)
    end
  end
end
