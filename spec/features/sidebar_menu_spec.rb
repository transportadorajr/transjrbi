require 'rails_helper'

describe 'Sidebar menu', flipper: %i[trips_dashboard maintenance] do
  let!(:tenant) { create(:tenant) }
  let!(:resources) do
    %w[
      freight_billing trips revenue_projection goals transport_documents manifests route_distances customers customer_groups product_groups
      macro_regions cities truck_groups revenue_goals excluded_issuers holidays drivers vehicles expenses commission_rules tonnage_rates
      insurance_rates freight_expenses company users vehicle_availability own_fleet
    ].index_with { |slug| create(:resource, slug:) }
  end

  def sidebar_items
    within('#sidebar') { all('.nav-link').map { |link| link.text.squish } }
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'sees every item of the menu' do
      visit root_path

      expect(sidebar_items).to eq(
        [
          'Inteligência', 'Faturamento', 'Viagens', 'Metas e projeções', 'Histórico da projeção', 'Metas',
          'Fiscal', 'CT-es', 'Manifestos', 'Trechos de km',
          'Frota', 'Veículos', 'Grupos de caminhões', 'Frota própria', 'Disponibilidade da frota',
          'Cadastros', 'Clientes', 'Grupos de clientes', 'Grupos de produtos', 'Macro regiões', 'Cidades',
          'Emissores desconsiderados', 'Feriados', 'Motoristas', 'Despesas',
          'Regras de comissão', 'Custos por tonelada', 'Alíquota de seguro', 'Despesas de frete',
          'Empresa', 'Usuários'
        ],
      )
    end
  end

  context 'when an admin with accesses is signed in' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:access, user: admin, resource: resources['freight_billing'], reads: true)
      create(:access, user: admin, resource: resources['drivers'], reads: true, creates: true)
      login_as(admin, scope: :user)
    end

    scenario 'sees only the granted items and the users management' do
      visit root_path

      expect(sidebar_items).to eq(%w[Inteligência Faturamento Cadastros Motoristas Usuários])
    end

    scenario 'cannot open a screen without access' do
      visit customers_path

      expect(page).to have_current_path(freight_billing_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when an operator with accesses is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before do
      create(:access, user: operator, resource: resources['manifests'], reads: true)
      create(:access, user: operator, resource: resources['company'], reads: true)
      login_as(operator, scope: :user)
    end

    scenario 'sees only the granted items' do
      visit root_path

      expect(sidebar_items).to eq(%w[Fiscal Manifestos Empresa])
    end

    scenario 'sees only the granted items on a phone screen', :js do
      use_mobile_screen

      visit root_path
      first('[data-bs-target="#sidebarOffcanvas"]').click

      within('#sidebarOffcanvas') do
        expect(page).to have_link('Manifestos', visible: :all)
        expect(page).to have_no_link('Faturamento', visible: :all)
        expect(page).to have_no_link('Usuários', visible: :all)
      end
    end
  end

  context 'when an operator with fleet accesses is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before do
      create(:access, user: operator, resource: resources['vehicles'], reads: true)
      create(:access, user: operator, resource: resources['vehicle_availability'], reads: true)
      login_as(operator, scope: :user)
    end

    scenario 'sees the vehicles and the fleet availability inside the fleet group' do
      visit root_path

      expect(sidebar_items).to eq(['Frota', 'Veículos', 'Disponibilidade da frota'])
    end

    scenario 'opens the fleet availability from the fleet group' do
      visit root_path
      within('.sidebar-desktop') do
        click_on 'Frota'
        click_on 'Disponibilidade da frota'
      end

      expect(page).to have_current_path(vehicle_availabilities_path)
    end
  end

  context 'when an operator without accesses is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before { login_as(operator, scope: :user) }

    scenario 'sees an empty menu' do
      visit root_path

      expect(sidebar_items).to be_empty
    end
  end
end
