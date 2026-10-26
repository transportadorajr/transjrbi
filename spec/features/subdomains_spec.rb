require 'rails_helper'

describe 'Subdomains' do
  let(:app_host) { Rails.application.config.x.app_host }
  let(:admin_host) { Rails.application.config.x.admin_host }

  context 'on the app subdomain' do
    scenario 'serves the app login screen' do
      visit new_user_session_path

      expect(page.current_host).to eq("http://#{app_host}")
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'on the bare domain' do
    scenario 'redirects to the same path on the app subdomain' do
      visit "http://#{Rails.application.config.x.domain}/users/sign_in?foo=bar"

      expect(page.current_host).to eq("http://#{app_host}")
      expect(page).to have_current_path('/users/sign_in?foo=bar')
    end

    scenario 'keeps the health check reachable' do
      visit "http://#{Rails.application.config.x.domain}/up"

      expect(page.status_code).to eq(200)
      expect(page.current_host).to eq("http://#{Rails.application.config.x.domain}")
    end
  end

  context 'on the admin subdomain' do
    scenario 'does not serve the app screens' do
      visit "http://#{admin_host}/customers"

      expect(page.status_code).to eq(404)
    end
  end
end
