require 'rails_helper'

describe 'Route distances' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Trechos de km', slug: 'route_distances') }
  let!(:arcelor) do
    create(:atua_customer, tenant:, code: 7001, name: 'ARCELORMITTAL BRASIL S.A.', document: '17.469.701/0066-12',
                           document_digits: '17469701006612')
  end
  let!(:gerdau) do
    create(:atua_customer, tenant:, code: 7002, name: 'GERDAU ACOS LONGOS S.A.', document: '07.358.761/0001-69',
                           document_digits: '07358761000169')
  end

  def document_on_route(**attributes)
    create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                     destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1300'), **attributes)
  end

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit route_distances_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not register a route' do
      expect do
        page.driver.submit :post, route_distances_path, { route_distance: { customer_code: '7001', distance_km: '450' } }
      end.not_to change(RouteDistance, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there is no route' do
      scenario 'shows the empty state message' do
        visit route_distances_path

        expect(RouteDistance.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are routes' do
      let!(:ipatinga) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1450')) }
      let!(:serra) do
        create(:route_distance, tenant:, customer_code: 7002, origin_city: 'SERRA', origin_state: 'ES', destination_city: 'CURITIBA',
                                destination_state: 'PR', distance_km: BigDecimal('1210.5'))
      end
      let!(:stranger) { create(:route_distance, tenant: other_tenant, customer_code: 7001, destination_city: 'MANAUS') }

      before do
        create_list(:atua_transport_document, 2, tenant:, route_distance: ipatinga)
        create(:atua_transport_document, tenant:, taker_code: 7001)
      end

      scenario 'lists the routes of the tenant from the tax menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'Trechos de km'
        end

        expect(page).to have_current_path(route_distances_path)
        expect(RouteDistance.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Cliente', 'Trecho', 'KM considerado', 'CT-es', 'Ações'],
            ['ARCELORMITTAL BRASIL S.A.', 'IPATINGA/MG → CAXIAS DO SUL/RS', '1.450,00 km', '2', 'Opções Alterar Excluir'],
            ['GERDAU ACOS LONGOS S.A.', 'SERRA/ES → CURITIBA/PR', '1.210,50 km', '0', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Novo Trecho', href: new_route_distance_path)
        expect(page).to have_link('Importar Planilha', href: '#routeDistanceImportModal')
        expect(page).to have_no_text('MANAUS')
      end

      scenario 'filters the routes by customer, origin and destination' do
        visit route_distances_path(customer_code: 7002)

        expect(html_table_to_rows).to eq(
          [
            ['Cliente', 'Trecho', 'KM considerado', 'CT-es', 'Ações'],
            ['GERDAU ACOS LONGOS S.A.', 'SERRA/ES → CURITIBA/PR', '1.210,50 km', '0', 'Opções Alterar Excluir'],
          ],
        )

        visit route_distances_path
        fill_in 'Cidade de origem', with: 'ipatin'
        fill_in 'Cidade de destino', with: 'caxias'
        click_on 'Aplicar Filtros'

        expect(RouteDistance.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Cliente', 'Trecho', 'KM considerado', 'CT-es', 'Ações'],
            ['ARCELORMITTAL BRASIL S.A.', 'IPATINGA/MG → CAXIAS DO SUL/RS', '1.450,00 km', '2', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'sorts the routes by the distance' do
        visit route_distances_path
        within('thead') { click_on 'KM considerado' }

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['ARCELORMITTAL BRASIL S.A.', 'GERDAU ACOS LONGOS S.A.'])
        expect(page).to have_current_path(route_distances_path(sort: :distance_km, direction: :desc))
      end

      scenario 'does not open a route of another tenant' do
        visit edit_route_distance_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when transport documents of the route are already imported' do
      let!(:document) { document_on_route }
      let!(:other_customer_document) { document_on_route(taker_code: 7002) }
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

      scenario 'registers the route and replaces the distance of its transport documents', :js do
        visit route_distances_path
        click_on 'Novo Trecho'
        within('#customer_code_select') do
          find('.select2-trigger').click
          find('.select2-search').fill_in(with: 'arcelor')
          find('.select2-option', text: 'ARCELORMITTAL').click
        end
        fill_in 'Cidade de origem', with: 'Ipatinga'
        fill_in 'UF de origem', with: 'mg'
        fill_in 'Cidade de destino', with: 'Caxias do Sul'
        fill_in 'UF de destino', with: 'RS'
        fill_in 'KM considerado', with: '1.450,00'

        expect do
          click_on 'Cadastrar Trecho'
          expect(page).to have_text('Trecho salvo e aplicado a 1 CT-e.')
        end.to change(RouteDistance, :count).by(1)

        expect(page).to have_current_path(route_distances_path)
        route_distance = RouteDistance.last
        expect(route_distance).to have_attributes(tenant:, customer_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                                  destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1450'))
        expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'),
                                                   route_distance_id: route_distance.id)
        expect(other_customer_document.reload).to have_attributes(distance_km: BigDecimal('1300'), route_distance_id: nil)

        visit transport_document_path(document)

        expect(dl_to_hash('#transport')).to include('DISTÂNCIA (KM)' => '1.450,00 KM do trecho cadastrado. KM do Atua: 1.300,00')
      end

      scenario 'shows the errors of an invalid route' do
        visit new_route_distance_path
        fill_in 'Cidade de origem', with: 'IPATINGA'
        fill_in 'UF de origem', with: 'M1'
        fill_in 'KM considerado', with: '0'

        expect { click_on 'Cadastrar Trecho' }.not_to change(RouteDistance, :count)

        expect(page).to have_text('Cliente não pode ficar em branco')
        expect(page).to have_text('UF de origem não é válido')
        expect(page).to have_text('KM considerado deve ser maior que 0')
        expect(document.reload.distance_km).to eq(BigDecimal('1300'))
      end

      scenario 'does not register the same route twice for the customer' do
        create(:route_distance, tenant:, customer_code: 7001)

        expect do
          page.driver.submit :post, route_distances_path,
                             { route_distance: { customer_code: '7001', origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Caxias do Sul',
                                                 destination_state: 'RS', distance_km: '900' } }
        end.not_to change(RouteDistance, :count)

        expect(page).to have_text('Este trecho já está cadastrado para o cliente')
      end

      context 'with a route applied' do
        let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1450')) }

        before { RouteDistances::ApplyCommand.call(tenant) }

        scenario 'changes the distance of the transport documents' do
          visit route_distances_path
          within("#route_distance_#{route_distance.id} .inline-actions") { click_on 'Alterar' }
          fill_in 'KM considerado', with: '1520,5'

          expect { click_on 'Salvar Alterações' }.not_to change(RouteDistance, :count)

          expect(page).to have_text('Trecho salvo e aplicado a 1 CT-e.')
          expect(route_distance.reload.distance_km).to eq(BigDecimal('1520.5'))
          expect(document.reload).to have_attributes(distance_km: BigDecimal('1520.5'), original_distance_km: BigDecimal('1300'))
        end

        scenario 'gives the distance from Atua back when the route changes to another destination' do
          visit edit_route_distance_path(route_distance)
          fill_in 'Cidade de destino', with: 'PORTO ALEGRE'

          expect { click_on 'Salvar Alterações' }.not_to change(RouteDistance, :count)

          expect(page).to have_text('Trecho salvo. Nenhum CT-e importado tem este cliente e trecho')
          expect(route_distance.reload.destination_city).to eq('PORTO ALEGRE')
          expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: nil, route_distance_id: nil)
        end

        scenario 'asks for confirmation and gives the transport documents their distance back' do
          visit route_distances_path

          expect(page).to have_css(
            "#route_distance_#{route_distance.id} a[data-turbo-confirm='Os CT-es deste trecho voltarão a usar o KM informado pelo Atua. " \
            "Deseja continuar?']",
          )

          expect { page.driver.submit :delete, route_distance_path(route_distance), {} }.to change(RouteDistance, :count).by(-1)

          expect(page).to have_current_path(route_distances_path)
          expect(page).to have_text('Trecho excluído. Os CT-es dele voltaram a usar o KM informado pelo Atua.')
          expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: nil, distance_adjusted_at: nil)
        end
      end
    end

    context 'when importing a spreadsheet' do
      let!(:document) { document_on_route }
      let!(:existing) do
        create(:route_distance, tenant:, customer_code: 7002, origin_city: 'SERRA', origin_state: 'ES', destination_city: 'CURITIBA',
                                destination_state: 'PR', distance_km: BigDecimal('100'))
      end

      scenario 'creates and updates the routes and reports the invalid rows' do
        path = xlsx_file([%w[Cliente Origem UF Destino UF KM], ['17.469.701/0066-12', 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', 1450],
                          ['07358761000169', 'SERRA', 'ES', 'CURITIBA', 'PR', 280], ['17469701006612', 'IPATINGA', 'MG', 'MANAUS', 'AM', 0]])

        visit route_distances_path
        within('#routeDistanceImportModal') do
          attach_file 'Planilha', path
          expect { click_on 'Importar' }.to change(RouteDistance, :count).by(1)
        end

        expect(page).to have_current_path(route_distances_path)
        expect(page).to have_text('Planilha importada: 1 trecho(s) criado(s) e 1 atualizado(s); 1 CT-e(s) usam o KM desses trechos.')
        expect(page).to have_text('Linha 4: KM considerado deve ser maior que 0.')
        expect(existing.reload.distance_km).to eq(BigDecimal('280'))
        expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1300'))
      end

      scenario 'registers the route of each transport document listed with its distance' do
        same_route_document = document_on_route(distance_km: BigDecimal('1250'))
        path = xlsx_file([['CTE ', 'KM ROTA EXECUTADA'], [document.number.to_i, 1450], [same_route_document.number.to_i, 1450], [88_888, 500]])

        visit route_distances_path
        within('#routeDistanceImportModal') do
          expect(page).to have_text('Envie uma planilha do Excel com as colunas: número do CT-e e KM a considerar.')
          attach_file 'Planilha', path
          expect { click_on 'Importar' }.to change(RouteDistance, :count).by(1)
        end

        expect(page).to have_current_path(route_distances_path)
        expect(page).to have_text('Planilha importada: 1 trecho(s) criado(s) e 0 atualizado(s); 2 CT-e(s) usam o KM desses trechos.')
        expect(page).to have_text('Linha 4: nenhum CT-e importado com o número 88888.')
        route_distance = RouteDistance.last
        expect(route_distance).to have_attributes(tenant:, customer_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                                  destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1450'))
        expect(document.reload).to have_attributes(distance_km: BigDecimal('1450'), route_distance_id: route_distance.id)
        expect(same_route_document.reload).to have_attributes(distance_km: BigDecimal('1450'), original_distance_km: BigDecimal('1250'))
      end

      scenario 'rejects a file that is not an Excel spreadsheet' do
        visit route_distances_path
        within('#routeDistanceImportModal') do
          attach_file 'Planilha', Rails.root.join('Gemfile')
          expect { click_on 'Importar' }.not_to change(RouteDistance, :count)
        end

        expect(page).to have_text('Planilha deve ser uma planilha do Excel (.xlsx, .xls)')
      end
    end
  end

  context 'when an operator without access is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before { login_as(operator, scope: :user) }

    scenario 'does not open the screen' do
      visit route_distances_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    context 'with read access to the routes' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }
      let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001) }

      scenario 'lists the routes without the management actions' do
        visit route_distances_path

        expect(RouteDistance.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)
        expect(page).to have_no_link('Novo Trecho')
        expect(page).to have_no_link('Importar Planilha')
        expect(page).to have_no_link('Alterar', exact: true)
      end

      scenario 'does not import a spreadsheet' do
        file = Rack::Test::UploadedFile.new(xlsx_file([['17469701006612', 'SERRA', 'ES', 'CURITIBA', 'PR', 450]]), original_filename: 'km.xlsx')

        expect do
          page.driver.submit :post, import_route_distances_path, { route_distance_import: { file: } }
        end.not_to change(RouteDistance, :count)
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit route_distances_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'CLIENTE')
      expect(page).to have_css('th', text: 'TRECHO')
      expect(page).to have_no_css('th', text: 'KM CONSIDERADO')
      expect(page).to have_no_css('th', text: 'CT-ES')

      click_on 'Ordenar por'
      within('.table-card-header') { click_on 'KM considerado' }

      expect(page).to have_current_path(route_distances_path(sort: :distance_km, direction: :desc))

      within("#route_distance_#{route_distance.id}") do
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_route_distance_path(route_distance))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
