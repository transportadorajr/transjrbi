require 'rails_helper'

describe 'Maintenance subdomain', :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:resources) do
    %w[maintenance maintenance_orders workshop_employees suppliers vehicles truck_groups drivers expenses transport_documents customers].index_with do |slug|
      create(:resource, slug:)
    end
  end

  def sidebar_items
    within('#sidebar') { all('.nav-link').map { |link| link.text.squish } }
  end

  context 'without a signed in user', flipper: :maintenance do
    scenario 'redirects to the login screen of the maintenance subdomain' do
      visit '/'

      expect(page).to have_current_path(new_user_session_path)
      expect(URI.parse(page.current_url).host).to eq(Rails.application.config.x.maintenance_host)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the maintenance home' do
      visit '/'

      expect(page.status_code).to eq(404)
    end

    scenario 'does not open the vehicles' do
      visit vehicles_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'opens the maintenance orders as the home page' do
      visit '/'

      expect(page).to have_current_path(maintenance_orders_path)
      expect(page).to have_css('h1.page-title', text: 'Ordens de serviço')
    end

    scenario 'sees only the maintenance items and the vehicles in the menu' do
      visit '/'

      expect(sidebar_items).to eq(['Ordens de serviço', 'Funcionários da oficina', 'Fornecedores', 'Veículos'])
    end

    scenario 'opens the vehicles from the menu' do
      visit '/'
      within('.sidebar-desktop') { click_on 'Veículos' }

      expect(page).to have_current_path(vehicles_path)
      expect(page).to have_css('h1.page-title', text: 'Veículos')
    end

    scenario 'does not open the truck groups' do
      visit truck_groups_path

      expect(page.status_code).to eq(404)
    end

    scenario 'does not open the screens of the app' do
      visit customers_path

      expect(page.status_code).to eq(404)
    end

    context 'when a vehicle has a driver, expenses and freights' do
      let!(:vehicle) do
        create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA')
      end
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, number: '74512', vehicle_code: vehicle.code, plate: 'EXU0F72', issued_at: Time.current)
      end

      before do
        create(:atua_expense, tenant:, history_name: 'PNEUS', plate: 'EXU0F72', total_cents: 200_000, cost_object: vehicle)
      end

      scenario 'shows the vehicle without linking to the screens of the app' do
        visit vehicle_path(vehicle)

        expect(page).to have_css('h1.page-title', text: 'Veículo EXU0F72')
        expect(page).to have_text('JOSE DA SILVA')
        expect(page).to have_no_link('JOSE DA SILVA')
        expect(page).to have_no_text('Despesas do veículo')
      end
    end
  end

  context 'when a user without access to the maintenance module is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:access, user: operator, resource: resources['maintenance_orders'], reads: true, creates: true)
      login_as(operator, scope: :user)
    end

    scenario 'is signed out and sent to the login screen' do
      visit '/'

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_text('Você não possui acesso ao módulo de manutenção.')
    end

    scenario 'is signed out when opening a maintenance screen' do
      visit maintenance_orders_path

      expect(page).to have_current_path(new_user_session_path)

      visit maintenance_orders_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when a user with access to the maintenance module only is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:, name: 'Carlos Operador') }

    before do
      create(:access, user: operator, resource: resources['maintenance'], creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'sees the welcome page with an empty menu' do
      visit '/'

      expect(page).to have_current_path('/')
      expect(page).to have_css('h1.page-title', text: 'Bem-vindo à manutenção, Carlos Operador!')
      expect(page).to have_text('Sem acesso à manutenção')
      expect(sidebar_items).to eq([])
    end

    scenario 'is sent back to the welcome page when opening a screen without access' do
      visit maintenance_orders_path

      expect(page).to have_current_path('/')
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when a workshop user with access to the suppliers only is signed in', flipper: :maintenance do
    let!(:workshop_user) { create(:user, tenant:) }

    before do
      create(:access, user: workshop_user, resource: resources['maintenance'], creates: false)
      create(:access, user: workshop_user, resource: resources['suppliers'], reads: true, creates: true)
      login_as(workshop_user, scope: :user)
    end

    scenario 'opens the suppliers as the home page' do
      visit '/'

      expect(page).to have_current_path(suppliers_path)
      expect(sidebar_items).to eq(['Fornecedores'])
    end
  end

  context 'when the owner opens the app', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    around do |example|
      Capybara.app_host = "http://#{Rails.application.config.x.app_host}"
      example.run
    end

    before { login_as(owner, scope: :user) }

    scenario 'does not show the maintenance in the menu' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Manutenção')
      expect(page).to have_no_link('Ordens de serviço')
    end

    scenario 'does not open the maintenance orders' do
      visit maintenance_orders_path

      expect(page.status_code).to eq(404)
    end
  end
end
