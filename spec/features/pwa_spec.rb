require 'rails_helper'

describe 'Progressive web app' do
  context 'without a signed in user' do
    scenario 'links the manifest and the app icons on the login screen' do
      visit new_user_session_path

      expect(page).to have_css('link[rel="manifest"][href="/manifest.json"]', visible: :hidden)
      expect(page).to have_css('link[rel="apple-touch-icon"][href="/apple-touch-icon.png"]', visible: :hidden)
      expect(page).to have_css('meta[name="theme-color"][content="#0b3fae"]', visible: :hidden)
      expect(page).to have_css('meta[name="apple-mobile-web-app-title"][content="TransJRBI"]', visible: :hidden)
      expect(page).to have_css('meta[name="application-name"][content="TransJRBI"]', visible: :hidden)
    end

    scenario 'serves the manifest that makes the app installable' do
      visit pwa_manifest_path(format: :json)

      manifest = JSON.parse(page.body)

      expect(page.status_code).to eq(200)
      expect(manifest).to include(
        'name' => 'TransJRBI',
        'short_name' => 'TransJRBI',
        'description' => 'Fretes, viagens e resultados da sua transportadora em um só lugar.',
        'lang' => 'pt-BR',
        'start_url' => '/',
        'scope' => '/',
        'display' => 'standalone',
        'theme_color' => '#0b3fae',
        'background_color' => '#000000',
      )
      expect(manifest['icons']).to contain_exactly(
        { 'src' => '/icon-192.png', 'type' => 'image/png', 'sizes' => '192x192' },
        { 'src' => '/icon.png', 'type' => 'image/png', 'sizes' => '512x512' },
        { 'src' => '/icon.png', 'type' => 'image/png', 'sizes' => '512x512', 'purpose' => 'maskable' },
      )
    end

    scenario 'serves the service worker' do
      visit pwa_service_worker_path(format: :js)

      expect(page.status_code).to eq(200)
      expect(page.response_headers['Content-Type']).to include('text/javascript')
      expect(page.body).to include("addEventListener('activate'")
    end
  end

  context 'when a user is signed in' do
    let!(:tenant) { create(:tenant) }
    let!(:user) { create(:user, tenant:) }

    before { login_as(user, scope: :user) }

    scenario 'links the manifest on the app screens' do
      visit root_path

      expect(page).to have_css('link[rel="manifest"][href="/manifest.json"]', visible: :hidden)
    end
  end
end
