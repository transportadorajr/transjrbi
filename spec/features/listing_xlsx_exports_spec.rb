require 'rails_helper'

describe 'Listing Excel exports' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', email: 'bruna@transjrbi.com.br', user_type: :owner) }
  let(:listings) do
    {
      cities_path: { name: 'Ipa' }, commission_rules_path: {}, customer_groups_path: {}, customers_path: {}, drivers_path: {},
      excluded_issuers_path: {}, expenses_path: {}, freight_expenses_path: {}, holidays_path: { year: 2026 }, macro_regions_path: {},
      manifests_path: {}, product_groups_path: {}, route_distances_path: {}, tonnage_rates_path: {}, truck_groups_path: {},
      users_path: { name: 'Bruna' }, vehicles_path: {}, transport_documents_path: {}
    }
  end

  before do
    %w[cities commission_rules customer_groups customers drivers excluded_issuers expenses freight_expenses holidays macro_regions manifests
       product_groups route_distances tonnage_rates truck_groups users vehicles transport_documents].each do |slug|
      create(:resource, name: slug.humanize, slug:, writable: false)
    end
    login_as(owner, scope: :user)
  end

  def expect_xlsx_download(filename)
    expect(page.status_code).to eq(200)
    expect(page.response_headers['Content-Type']).to eq(Mime[:xlsx].to_s)
    expect(page.response_headers['Content-Disposition']).to include('attachment', "filename=\"#{filename}-#{Date.current.iso8601}.xlsx\"")
    expect(downloaded_xlsx_rows.first).not_to include('ID', 'Id')
  end

  context 'with the Excel export enabled', :xlsx_service, flipper: { xlsx_export: :tenant } do
    scenario 'shows the Excel export button with the applied filters on every listing' do
      listings.each do |path, filters|
        visit send(path, **filters, page: 2)

        expect(page).to have_link('Exportar Excel', href: send(path, **filters, format: :xlsx))
      end
    end

    context 'when there are cities' do
      let!(:macro_region) { create(:macro_region, tenant:, name: 'VALE DO AÇO/MG', city_names: ['Ipatinga']) }
      let!(:betim) { create(:city, tenant:, name: 'Betim', state: 'MG') }
      let!(:stranger) { create(:city, tenant: other_tenant, name: 'Cubatão', state: 'SP') }

      scenario 'exports the cities of the tenant with the name of their macro region' do
        visit cities_path(format: :xlsx)

        expect_xlsx_download('cidades')
        expect(City.count).to eq(3)
        expect(downloaded_xlsx_rows.first).to eq(['Macro região', 'Nome', 'UF', 'Criado em', 'Atualizado em'])
        expect(downloaded_xlsx_records.map { |record| record.slice('Macro região', 'Nome', 'UF') }).to eq(
          [{ 'Macro região' => nil, 'Nome' => 'Betim', 'UF' => 'MG' }, { 'Macro região' => 'VALE DO AÇO/MG', 'Nome' => 'Ipatinga', 'UF' => 'MG' }],
        )
      end

      scenario 'exports only the cities that match the filters' do
        visit cities_path(format: :xlsx, name: 'Beti')

        expect(downloaded_xlsx_records.pluck('Nome')).to eq(%w[Betim])
      end
    end

    context 'when there are commission rules' do
      let!(:commission_rule) do
        create(:commission_rule, tenant:, name: 'Nacional', percentage: 2, customer_group: create(:customer_group, tenant:, name: 'USIMINAS'))
      end

      scenario 'exports the commission rules with the name of their customer group' do
        visit commission_rules_path(format: :xlsx)

        expect_xlsx_download('regras-de-comissao')
        expect(CommissionRule.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Grupo de clientes' => 'USIMINAS', 'Nome' => 'Nacional', 'Comissão' => 0.02)
      end
    end

    context 'when there are customer groups' do
      let!(:customer_group) { create(:customer_group, tenant:, name: 'GERDAU', terms: %w[GERDAU]) }

      before do
        create(:atua_customer, tenant:, code: 7100, customer_group:)
        create(:atua_customer, tenant:, code: 7200, customer_group:)
      end

      scenario 'exports the customer groups with how many customers each one has' do
        visit customer_groups_path(format: :xlsx)

        expect_xlsx_download('grupos-de-clientes')
        expect(CustomerGroup.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'GERDAU', 'Termos' => 'GERDAU', 'Clientes' => 2)
      end
    end

    context 'when there are customers' do
      let!(:customer) do
        create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.', document: '17.469.701/0066-12',
                               customer_group: create(:customer_group, tenant:, name: 'ARCELOR'))
      end
      let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: 'CLIENTE DE OUTRA EMPRESA') }

      scenario 'exports the customers of the tenant with the name of their group' do
        visit customers_path(format: :xlsx)

        expect_xlsx_download('clientes')
        expect(Atua::Customer.count).to eq(2)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'ARCELORMITTAL BRASIL S.A.', 'CPF/CNPJ' => '17.469.701/0066-12', 'Grupo' => 'ARCELOR')
      end
    end

    context 'when there are drivers' do
      before do
        create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64',
                              driver_license: '604269044')
        create(:atua_vehicle, tenant:, plate: 'BEV4G50', driver_code: 760, driver_name: 'JOSE DA SILVA')
      end

      scenario 'exports one row per driver with the plates of the vehicles' do
        visit drivers_path(format: :xlsx)

        expect_xlsx_download('motoristas')
        expect(Atua::Vehicle.count).to eq(2)
        expect(downloaded_xlsx_rows.first).to eq(['Código do motorista', 'Motorista', 'Nome de exibição', 'CPF do motorista', 'CNH', 'Placas', 'Veículos'])
        expect(downloaded_xlsx_records.sole).to include('Código do motorista' => 760, 'Motorista' => 'JOSE DA SILVA', 'CPF do motorista' => '808.542.250-64',
                                                        'CNH' => '604269044', 'Veículos' => 2)
        expect(downloaded_xlsx_records.sole['Placas'].split(', ')).to contain_exactly('BEV4G50', 'EXU0F72')
      end
    end

    context 'when there are excluded issuers' do
      let!(:excluded_issuer) { create(:excluded_issuer, tenant:, code: 6_001, name: 'MAYCON DORALINO SANTOS LORENA') }

      before { create(:atua_transport_document, tenant:, issuer_code: 6_001, freight_cents: 150_000) }

      scenario 'exports the excluded issuers with the totals of their documents' do
        visit excluded_issuers_path(format: :xlsx)

        expect_xlsx_download('emissores-desconsiderados')
        expect(ExcludedIssuer.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Código no Atua' => 6_001, 'Emissor' => 'MAYCON DORALINO SANTOS LORENA', 'Documentos' => 1,
                                                        'Frete bruto' => 1_500)
      end
    end

    context 'when there are expenses' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
      let!(:expense) { create(:atua_expense, tenant:, code: 590_001, plate: 'EXU0F72', total_cents: 725_000, cost_object: vehicle) }

      scenario 'exports the expenses with their translated allocation and origin' do
        visit expenses_path(format: :xlsx)

        expect_xlsx_download('despesas')
        expect(Atua::Expense.count).to eq(1)
        expect(downloaded_xlsx_rows.first).not_to include('Cost object type')
        expect(downloaded_xlsx_records.sole).to include('Código' => 590_001, 'Placa' => 'EXU0F72', 'Valor total' => 7_250, 'Alocação' => 'Veículo',
                                                        'Origem' => 'EXU0F72')
      end
    end

    context 'when there are freight expenses' do
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, number: '74130', taker_name: 'USIMINAS', issued_at: Time.zone.local(2026, 10, 1, 8, 30))
      end
      let!(:freight_expense) { create(:freight_expense, tenant:, transport_document:, amount_cents: 2_000) }

      scenario 'exports the freight expenses with the number, the issue and the taker of their transport document' do
        visit freight_expenses_path(format: :xlsx)

        expect_xlsx_download('despesas-de-frete')
        expect(FreightExpense.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('CT-e' => '74130', 'Valor' => 20, 'Tomador' => 'USIMINAS',
                                                        'CT-e emitido em' => DateTime.new(2026, 10, 1, 8, 30))
      end
    end

    context 'when there are holidays' do
      let!(:holiday) { create(:holiday, tenant:, date: Date.new(2026, 11, 20), name: 'Consciência Negra') }

      scenario 'exports the holidays of the year with their translated scope and kind' do
        visit holidays_path(year: 2026)
        click_on 'Exportar Excel'

        expect_xlsx_download('feriados')
        expect(downloaded_xlsx_records.map { |record| record.slice('Data', 'Nome') }).to include('Data' => Date.new(2026, 11, 20), 'Nome' => 'Consciência Negra')
        expect(downloaded_xlsx_records.pluck('Data')).to all(have_attributes(year: 2026))
      end

      scenario 'answers not acceptable to a PDF of the holidays' do
        visit holidays_path(format: :pdf)

        expect(page.status_code).to eq(406)
      end
    end

    context 'when there are macro regions' do
      let!(:macro_region) { create(:macro_region, tenant:) }

      scenario 'exports the macro regions with the names of their cities' do
        visit macro_regions_path(format: :xlsx)

        expect_xlsx_download('macro-regioes')
        expect(MacroRegion.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'VALE DO AÇO/MG', 'UF' => 'MG', 'Restante do estado' => false,
                                                        'Cidades' => 'Coronel Fabriciano, Ipatinga, Timóteo')
      end
    end

    context 'when there are manifests' do
      let!(:manifest) { create(:atua_manifest, :with_transport_document, tenant:, number: '40800', plate: 'RHJ4E07') }

      scenario 'exports the manifests with the totals of the trip' do
        visit manifests_path(format: :xlsx)

        expect_xlsx_download('manifestos')
        expect(Atua::Manifest.count).to eq(1)
        expect(downloaded_xlsx_rows.first).to include('Número', 'Placa', 'Motorista', 'Origem', 'Destino', 'Grupo de clientes', 'KM rodado', 'Frete bruto',
                                                      'Frete líquido', 'Bruto/km', 'Líquido/km', 'Duração (horas)', 'Líquido/hora')
        expect(downloaded_xlsx_records.sole).to include('Número' => '40800', 'Placa' => 'RHJ4E07')
      end
    end

    context 'when there are product groups' do
      let!(:product_group) { create(:product_group, tenant:, name: 'BOBINAS') }

      before { create(:product_group, tenant:, name: 'BOBINA A QUENTE', parent: product_group) }

      scenario 'exports the product groups with how many subgroups each one has' do
        visit product_groups_path(format: :xlsx)

        expect_xlsx_download('grupos-de-produtos')
        expect(ProductGroup.count).to eq(2)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'BOBINAS', 'Subgrupos' => 1, 'CT-es' => 0)
      end
    end

    context 'when there are route distances' do
      let!(:route_distance) { create(:route_distance, tenant:) }

      scenario 'exports the route distances with the name of the customer and how many documents use them' do
        visit route_distances_path(format: :xlsx)

        expect_xlsx_download('trechos-de-km')
        expect(RouteDistance.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Cidade de origem' => 'IPATINGA', 'Cidade de destino' => 'CAXIAS DO SUL', 'CT-es' => 0)
      end
    end

    context 'when there are tonnage rates' do
      let!(:tonnage_rate) do
        create(:tonnage_rate, tenant:, customer_group: create(:customer_group, tenant:, name: 'BRASILTEC'), valid_month: Date.current.beginning_of_month)
      end

      scenario 'exports the tonnage rates with the name of their customer group' do
        visit tonnage_rates_path(format: :xlsx)

        expect_xlsx_download('custos-por-tonelada')
        expect(TonnageRate.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'Brasiltec', 'Grupo de clientes' => 'BRASILTEC', 'Vigência' => Date.current.beginning_of_month)
      end
    end

    context 'when there are truck groups' do
      let!(:truck_group) { create(:truck_group, tenant:, plates: %w[EXU0F72 BEV4G50]) }

      scenario 'exports the truck groups with their plates as text' do
        visit truck_groups_path(format: :xlsx)

        expect_xlsx_download('grupos-de-caminhoes')
        expect(TruckGroup.count).to eq(1)
        expect(downloaded_xlsx_records.sole).to include('Nome' => 'Rodotrem', 'Placas' => 'EXU0F72, BEV4G50')
      end
    end

    context 'when there are other users in the company' do
      let!(:operator) { create(:user, tenant:, name: 'Carla Operadora', email: 'carla@transjrbi.com.br') }
      let!(:stranger) { create(:user, tenant: other_tenant, name: 'Pedro Estranho') }

      scenario 'exports the users of the company without their credentials' do
        visit users_path(format: :xlsx)

        expect_xlsx_download('usuarios')
        expect(User.count).to eq(3)
        expect(downloaded_xlsx_records.map { |record| record.slice('Nome', 'E-mail', 'Perfil') }).to eq(
          [{ 'Nome' => 'Bruna Dona', 'E-mail' => 'bruna@transjrbi.com.br', 'Perfil' => 'Proprietário' },
           { 'Nome' => 'Carla Operadora', 'E-mail' => 'carla@transjrbi.com.br', 'Perfil' => 'Operador' }],
        )
        expect(downloaded_xlsx_rows.first).to eq(
          ['E-mail', 'Resetar senha enviado em', 'Lembrar criado em', 'Contagem de acessos', 'Atualmente logado em', 'Último acesso em', 'Confirmado em',
           'Confirmação enviada em', 'E-mail não confirmado', 'Criado em', 'Atualizado em', 'Nome', 'Telefone', 'Perfil', 'Ativado em',
           'Troca de senha solicitada em'],
        )
      end
    end

    context 'when there are transport documents' do
      let!(:macro_region) { create(:macro_region, tenant:, name: 'VALE DO AÇO/MG') }
      let!(:document) do
        create(:atua_transport_document, tenant:, number: '74130', plate: 'EXU0F72', freight_cents: 55_504, origin_macro_region: macro_region,
                                         posted_on: Date.new(2026, 10, 1))
      end
      let!(:canceled) { create(:atua_transport_document, tenant:, number: '74131', canceled_at: Time.zone.local(2026, 10, 5, 9)) }
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74133') }

      before { create(:freight_expense, tenant:, transport_document: document, amount_cents: 5_504) }

      scenario 'exports the valid transport documents of the tenant with the net freight' do
        visit transport_documents_path(format: :xlsx)

        expect_xlsx_download('ct-es')
        expect(Atua::TransportDocument.count).to eq(3)
        expect(downloaded_xlsx_records.sole).to include('Número' => '74130', 'Placa' => 'EXU0F72', 'Frete' => 555.04, 'Dt Emissão' => Date.new(2026, 10, 1),
                                                        'Macrorregião de origem' => 'VALE DO AÇO/MG', 'Frete líquido' => 500)
      end

      context 'when an operator reads the transport documents but not the freight expenses' do
        let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

        before do
          create(:access, user: operator, resource: Resource.find_by!(slug: 'transport_documents'), reads: true)
          login_as(operator, scope: :user)
        end

        scenario 'leaves the net freight out of the spreadsheet' do
          visit transport_documents_path(format: :xlsx)

          expect(downloaded_xlsx_rows.first).to include('Frete')
          expect(downloaded_xlsx_rows.first).not_to include('Frete líquido')
        end
      end
    end
  end

  context 'with the Excel export disabled' do
    scenario 'neither shows the button nor exports the spreadsheet of any listing' do
      listings.each do |path, filters|
        visit send(path, **filters)

        expect(page).to have_link('Exportar PDF') unless path == :holidays_path
        expect(page).to have_no_link('Exportar Excel')
      end

      visit transport_documents_path(format: :xlsx)

      expect(page.status_code).to eq(406)
    end
  end

  context 'when an operator cannot read the listing', :xlsx_service, flipper: { xlsx_export: :tenant } do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    scenario 'is sent back with an access denied message' do
      visit cities_path(format: :xlsx)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end
end
