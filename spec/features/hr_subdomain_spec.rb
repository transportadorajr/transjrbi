require 'rails_helper'

describe 'HR subdomain', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:resources) do
    %w[hr maintenance maintenance_orders vehicles truck_groups customers].index_with { |slug| create(:resource, slug:) }
  end

  def sidebar_items
    within('#sidebar') { all('.nav-link').map { |link| link.text.squish } }
  end

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects to the login screen of the HR subdomain' do
      visit '/'

      expect(page).to have_current_path(new_user_session_path)
      expect(URI.parse(page.current_url).host).to eq(Rails.application.config.x.hr_host)
    end
  end

  context 'when a user signs in through the HR login screen', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'Ana Dona') }

    scenario 'lands on the HR home' do
      visit new_user_session_path
      fill_in 'E-mail', with: owner.email
      fill_in 'Senha', with: 'Senha123!'
      click_on 'Entrar'

      expect(page).to have_current_path('/')
      expect(page).to have_css('h1.page-title', text: 'Bem-vindo ao RH, Ana Dona!')
    end
  end

  context 'when the HR flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the HR home' do
      visit '/'

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'Ana Dona') }

    before { login_as(owner, scope: :user) }

    scenario 'sees the HR welcome page with an empty menu' do
      visit '/'

      expect(page).to have_current_path('/')
      expect(page).to have_css('h1.page-title', text: 'Bem-vindo ao RH, Ana Dona!')
      expect(sidebar_items).to eq([])
    end

    scenario 'does not open the vehicles' do
      visit vehicles_path

      expect(page.status_code).to eq(404)
    end

    scenario 'does not open the maintenance orders' do
      visit maintenance_orders_path

      expect(page.status_code).to eq(404)
    end

    scenario 'does not open the screens of the app' do
      visit truck_groups_path

      expect(page.status_code).to eq(404)
    end

    scenario 'opens the account password screen' do
      visit edit_account_password_path

      expect(page).to have_current_path(edit_account_password_path)
      expect(page.status_code).to eq(200)
    end
  end

  context 'when the HR access resource is not registered', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'Ana Dona') }

    before do
      resources['hr'].destroy!
      login_as(owner, scope: :user)
    end

    scenario 'lets the owner enter the HR module' do
      visit '/'

      expect(Resource.exists?(slug: 'hr')).to be(false)
      expect(page).to have_current_path('/')
      expect(page).to have_css('h1.page-title', text: 'Bem-vindo ao RH, Ana Dona!')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'Ana Dona') }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'sees the HR welcome page' do
      visit '/'

      expect(page).to have_css('h1.page-title', text: 'Bem-vindo ao RH, Ana Dona!')
      expect(page).to have_text('Sem acesso ao RH')
    end
  end

  context 'when a user without access to the HR module is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:access, user: operator, resource: resources['maintenance'], creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'is signed out and sent to the login screen' do
      visit '/'

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_text('Você não possui acesso ao módulo de RH.')

      visit '/'

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when a user with access to the HR module is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:, name: 'Carlos Operador') }

    before do
      create(:access, user: operator, resource: resources['hr'], creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'sees the HR welcome page' do
      visit '/'

      expect(page).to have_current_path('/')
      expect(page).to have_css('h1.page-title', text: 'Bem-vindo ao RH, Carlos Operador!')
      expect(page).to have_text('Sem acesso ao RH')
      expect(sidebar_items).to eq([])
    end
  end

  context 'when the owner opens the maintenance subdomain', flipper: %i[hr maintenance] do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    around do |example|
      Capybara.app_host = "http://#{Rails.application.config.x.maintenance_host}"
      example.run
    end

    before { login_as(owner, scope: :user) }

    scenario 'keeps the maintenance orders as the home page' do
      visit '/'

      expect(page).to have_current_path(maintenance_orders_path)
    end
  end

  context 'when the owner opens the app', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    around do |example|
      Capybara.app_host = "http://#{Rails.application.config.x.app_host}"
      example.run
    end

    before { login_as(owner, scope: :user) }

    scenario 'does not show the HR in the menu' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Módulo de RH')
    end
  end
end
