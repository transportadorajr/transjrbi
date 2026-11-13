require 'rails_helper'

describe 'Sidebar menu', flipper: %i[trips_dashboard revenue_projection] do
  let!(:tenant) { create(:tenant) }
  let!(:resources) do
    %w[
      freight_billing trips revenue_projection transport_documents manifests route_distances customers customer_groups product_groups
      macro_regions cities truck_groups excluded_issuers holidays drivers vehicles expenses commission_rules tonnage_rates
      insurance_rates freight_expenses company users
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
          'Inteligência', 'Faturamento', 'Viagens', 'Projeção de faturamento', 'Histórico da projeção',
          'Fiscal', 'CT-es', 'Manifestos', 'Trechos de km',
          'Cadastros', 'Clientes', 'Grupos de clientes', 'Grupos de produtos', 'Macro regiões', 'Cidades',
          'Grupos de caminhões', 'Emissores desconsiderados', 'Feriados', 'Motoristas', 'Veículos', 'Despesas',
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

  context 'when an operator without accesses is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before { login_as(operator, scope: :user) }

    scenario 'sees an empty menu' do
      visit root_path

      expect(sidebar_items).to be_empty
    end
  end
end
