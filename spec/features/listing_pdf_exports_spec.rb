require 'rails_helper'

describe 'Listing PDF exports' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', email: 'bruna@transjrbi.com.br', user_type: :owner) }

  before do
    %w[cities commission_rules customer_groups customers drivers excluded_issuers expenses freight_expenses macro_regions manifests product_groups
       route_distances tonnage_rates truck_groups users vehicles transport_documents].each do |slug|
      create(:resource, name: slug.humanize, slug:, writable: false)
    end
    login_as(owner, scope: :user)
  end

  def pdf_text
    PDF::Inspector::Text.analyze(page.body).strings.join
  end

  def pdf_page_size
    PDF::Inspector::Page.analyze(page.body).pages.first[:size]
  end

  def expect_pdf_response(orientation)
    expect(page.status_code).to eq(200)
    expect(page.response_headers['Content-Type']).to include('application/pdf')
    expect(page.response_headers['Content-Disposition']).to include('inline')

    width, height = pdf_page_size
    expect(orientation == :landscape ? width > height : width < height).to be(true)
  end

  scenario 'shows the PDF export button with the applied filters on every listing' do
    {
      cities_path: { name: 'Ipa' }, commission_rules_path: {}, customer_groups_path: {}, customers_path: {}, drivers_path: {},
      excluded_issuers_path: {}, expenses_path: {}, freight_expenses_path: {}, macro_regions_path: {}, manifests_path: {}, product_groups_path: {},
      route_distances_path: {}, tonnage_rates_path: {}, truck_groups_path: {}, users_path: { name: 'Bruna' }, vehicles_path: {},
      transport_documents_path: {}
    }.each do |path, filters|
      visit send(path, **filters, page: 2)

      expect(page).to have_link('Exportar PDF', href: send(path, **filters, format: :pdf))
    end
  end

  context 'when there are cities' do
    let!(:ipatinga) { create(:city, tenant:, name: 'Ipatinga', state: 'MG') }
    let!(:betim) { create(:city, tenant:, name: 'Betim', state: 'MG') }
    let!(:stranger) { create(:city, tenant: other_tenant, name: 'Cubatão', state: 'SP') }

    scenario 'exports the cities of the tenant on a portrait page' do
      visit cities_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(City.count).to eq(3)
      expect(pdf_text).to include('Relatório de Cidades', 'Ipatinga', 'Betim', '2 registros listados.')
      expect(pdf_text).not_to include('Cubatão')
    end

    scenario 'exports only the cities that match the filters' do
      visit cities_path(format: :pdf, name: 'Beti')

      expect(pdf_text).to include('Betim', '1 registro listado.')
      expect(pdf_text).not_to include('Ipatinga')
    end
  end

  context 'when there are commission rules' do
    let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: create(:customer_group, tenant:, name: 'USIMINAS')) }

    scenario 'exports the commission rules on a landscape page' do
      visit commission_rules_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(CommissionRule.count).to eq(1)
      expect(pdf_text).to include('Relatório de Regras de comissão', 'Nacional', 'USIMINAS', 'Ativ', '1 registro listado.')
    end
  end

  context 'when there are customer groups' do
    let!(:customer_group) { create(:customer_group, tenant:, name: 'GERDAU', terms: %w[GERDAU]) }

    scenario 'exports the customer groups on a portrait page' do
      visit customer_groups_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(CustomerGroup.count).to eq(1)
      expect(pdf_text).to include('Relatório de Grupos de clientes', 'GERDAU', '1 registro listado.')
    end
  end

  context 'when there are customers' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.', document: '17.469.701/0066-12') }

    scenario 'exports the customers on a landscape page' do
      visit customers_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(Atua::Customer.count).to eq(1)
      expect(pdf_text).to include('Relatório de Clientes', 'ARCELORMITTAL BRASIL S.A.', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', '1 registro listado.')
    end
  end

  context 'when there are drivers' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA') }

    scenario 'exports the drivers on a landscape page' do
      visit drivers_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(Atua::Vehicle.count).to eq(1)
      expect(pdf_text).to include('Relatório de Motoristas', 'JOSE DA SILVA', '760', 'EXU0F72', '1 registro listado.')
    end
  end

  context 'when there are excluded issuers' do
    let!(:excluded_issuer) { create(:excluded_issuer, tenant:, code: 6_001, name: 'MAYCON DORALINO SANTOS LORENA') }

    scenario 'exports the excluded issuers on a portrait page' do
      visit excluded_issuers_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(ExcludedIssuer.count).to eq(1)
      expect(pdf_text).to include('Relatório de Emissores desconsiderados', 'MAYCON DORALINO SANTOS LORENA', '6001', '1 registro listado.')
    end
  end

  context 'when there are expenses' do
    let!(:expense) { create(:atua_expense, tenant:, code: 590_001, plate: 'EXU0F72') }

    scenario 'exports the expenses on a landscape page' do
      visit expenses_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(Atua::Expense.count).to eq(1)
      expect(pdf_text).to include('Relatório de Despesas', 'COMBUSTIVEL - DIESEL', '590001', '01/10/2026', 'EXU0F72', 'R$ 7.250,00', '1 registro listado.')
    end
  end

  context 'when there are freight expenses' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130') }
    let!(:freight_expense) { create(:freight_expense, tenant:, transport_document:, amount_cents: 2_000) }

    scenario 'exports the freight expenses and their total on a landscape page' do
      visit freight_expenses_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(FreightExpense.count).to eq(1)
      expect(pdf_text).to include('Relatório de Despesas de frete', '74130', 'R$ 20,00', 'TotalR$ 20,00', '1 registro listado.')
    end
  end

  context 'when there are macro regions' do
    let!(:macro_region) { create(:macro_region, tenant:) }

    scenario 'exports the macro regions on a portrait page' do
      visit macro_regions_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(MacroRegion.count).to eq(1)
      expect(pdf_text).to include('Relatório de Macro regiões', 'VALE DO AÇO/MG', '1 registro listado.')
    end
  end

  context 'when there are manifests' do
    let!(:manifest) { create(:atua_manifest, :with_transport_document, tenant:, number: '40800', plate: 'RHJ4E07') }

    scenario 'exports the manifests on a landscape page' do
      visit manifests_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(Atua::Manifest.count).to eq(1)
      expect(pdf_text).to include('Relatório de Manifestos', '40800', 'JR TRANSPORTES', 'RHJ4E07', 'Líquido/km', '1 registro listado.')
    end
  end

  context 'when there are product groups' do
    let!(:product_group) { create(:product_group, tenant:, name: 'BOBINAS') }

    scenario 'exports the product groups on a portrait page' do
      visit product_groups_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(ProductGroup.count).to eq(1)
      expect(pdf_text).to include('Relatório de Grupos de produtos', 'BOBINAS', '1 registro listado.')
    end
  end

  context 'when there are route distances' do
    let!(:route_distance) { create(:route_distance, tenant:) }

    scenario 'exports the route distances on a portrait page' do
      visit route_distances_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(RouteDistance.count).to eq(1)
      expect(pdf_text).to include('Relatório de Trechos de km', 'IPATINGA', 'CAXIAS DO SUL', '1 registro listado.')
    end
  end

  context 'when there are tonnage rates' do
    let!(:tonnage_rate) do
      create(:tonnage_rate, tenant:, customer_group: create(:customer_group, tenant:, name: 'BRASILTEC'), valid_month: Date.current.beginning_of_month)
    end

    scenario 'exports the tonnage rates on a landscape page' do
      visit tonnage_rates_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(TonnageRate.count).to eq(1)
      expect(pdf_text).to include('Relatório de Custos por tonelada', 'Brasiltec', 'BRASILTEC', '1 registro listado.')
    end
  end

  context 'when there are truck groups' do
    let!(:truck_group) { create(:truck_group, tenant:) }

    scenario 'exports the truck groups on a portrait page' do
      visit truck_groups_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(TruckGroup.count).to eq(1)
      expect(pdf_text).to include('Relatório de Grupos de caminhões', 'Rodotrem', '1 registro listado.')
    end
  end

  context 'when there are other users in the company' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora', email: 'carla@transjrbi.com.br') }
    let!(:stranger) { create(:user, tenant: other_tenant, name: 'Pedro Estranho') }

    scenario 'exports the users of the company on a portrait page' do
      visit users_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(User.count).to eq(3)
      expect(pdf_text).to include('Relatório de Usuários', 'Bruna Dona', 'bruna@transjrbi.com.br', 'Carla Operadora', 'carla@transjrbi.com.br',
                                  '2 registros listados.')
      expect(pdf_text).not_to include('Pedro Estranho')
    end
  end

  context 'when there are vehicles with transport documents this year' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', category: 'Caminhão / Cavalo', ownership: 'Próprio') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, vehicle_code: vehicle.code, issued_at: Time.current) }

    scenario 'exports the vehicles on a landscape page' do
      visit vehicles_path(format: :pdf)

      expect_pdf_response(:landscape)
      expect(Atua::Vehicle.count).to eq(1)
      expect(pdf_text).to include('Relatório de Veículos', 'EXU0F72', 'Caminhão / Cavalo', 'Próprio', '1 registro listado.')
    end
  end

  context 'when there are no records' do
    scenario 'exports a PDF telling that nothing was found' do
      visit truck_groups_path(format: :pdf)

      expect_pdf_response(:portrait)
      expect(TruckGroup.count).to eq(0)
      expect(pdf_text).to include('Relatório de Grupos de caminhões', 'Nenhum registro encontrado', 'Nenhum registro listado.')
    end
  end

  context 'when an operator cannot read the listing' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    scenario 'is sent back with an access denied message' do
      visit cities_path(format: :pdf)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end
end
