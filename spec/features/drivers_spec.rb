require 'rails_helper'

describe 'Drivers' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Motoristas', slug: 'drivers', writable: false) }

  context 'without a signed in user' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }

    scenario 'redirects the listing to the login screen' do
      visit drivers_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit driver_path(760)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no drivers' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: nil) }

      scenario 'shows the empty state message' do
        visit drivers_path

        expect(Atua::Vehicle.count).to eq(1)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are drivers linked to the vehicles' do
      let!(:truck) do
        create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64',
                              driver_document_digits: '80854225064', driver_license: '604269044')
      end
      let!(:spare_truck) do
        create(:atua_vehicle, tenant:, plate: 'AGL9451', driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64',
                              driver_document_digits: '80854225064', driver_license: '604269044')
      end
      let!(:other_truck) do
        create(:atua_vehicle, tenant:, plate: 'RHJ4E07', driver_code: 701, driver_name: 'ANA SOUZA', driver_document: nil,
                              driver_document_digits: nil, driver_license: nil)
      end
      let!(:removed) { create(:atua_vehicle, tenant:, plate: 'QQI0395', driver_code: 702, driver_name: 'PEDRO REMOVIDO', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_vehicle, tenant: other_tenant, plate: 'ZIZ7D35', driver_code: 703, driver_name: 'MOTORISTA DE OUTRA EMPRESA') }

      scenario 'lists one row per driver of the active vehicles of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Motoristas'
        end

        expect(page).to have_current_path(drivers_path)
        expect(Atua::Vehicle.count).to eq(5)
        expect(html_table_to_rows).to eq(
          [
            ['Motorista', 'CPF do motorista', 'CNH', 'Placas', 'Ações'],
            ['ANA SOUZA Código 701', '-', '-', 'RHJ4E07', ''],
            ['JOSE DA SILVA Código 760', '808.542.250-64', '604269044', 'AGL9451, EXU0F72', ''],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: driver_path(760), title: 'Visualizar')
        expect(page).to have_no_text('PEDRO REMOVIDO')
        expect(page).to have_no_text('MOTORISTA DE OUTRA EMPRESA')
      end

      scenario 'filters the drivers by name' do
        visit drivers_path
        fill_in 'Nome do motorista', with: 'ana'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Motorista', 'CPF do motorista', 'CNH', 'Placas', 'Ações'],
            ['ANA SOUZA Código 701', '-', '-', 'RHJ4E07', ''],
          ],
        )
      end

      scenario 'filters the drivers by document' do
        visit drivers_path
        fill_in 'CPF do motorista', with: '808.542.250-64'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Motorista', 'CPF do motorista', 'CNH', 'Placas', 'Ações'],
            ['JOSE DA SILVA Código 760', '808.542.250-64', '604269044', 'AGL9451, EXU0F72', ''],
          ],
        )
      end

      scenario 'does not show a driver only on vehicles removed from Atua' do
        visit driver_path(702)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show a driver of another tenant' do
        visit driver_path(703)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create a driver' do
        expect { page.driver.submit :post, drivers_path, {} }.not_to change(Atua::Vehicle, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when a driver has vehicles and transport documents' do
      let!(:vehicles_resource) { create(:resource, name: 'Veículos', slug: 'vehicles', writable: false) }
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
      let!(:truck) do
        create(:atua_vehicle, tenant:, plate: 'EXU0F72', category: 'Caminhão / Cavalo', brand: 'VOLVO', model: 'FH 540', ownership: 'Próprio',
                              driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64', driver_license: '604269044')
      end
      let!(:trailer) do
        create(:atua_vehicle, tenant:, plate: 'BEV4G50', category: 'Carreta', brand: nil, model: nil, ownership: 'Terceiro',
                              driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64', driver_license: '604269044')
      end
      let!(:latest_document) do
        create(:atua_transport_document, tenant:, number: '74130', issued_at: Time.zone.local(2026, 10, 2, 8), plate: 'EXU0F72',
                                         origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG',
                                         freight_cents: 555_040, driver_code: 760)
      end
      let!(:oldest_document) do
        create(:atua_transport_document, tenant:, number: '74100', issued_at: Time.zone.local(2026, 9, 28, 14, 30), plate: 'EXU0F72',
                                         origin_city: nil, origin_state: nil, destination_city: nil, destination_state: nil,
                                         freight_cents: 120_000, driver_code: 760)
      end

      before do
        create(:atua_transport_document, tenant:, number: '74199', driver_code: 701)
        create(:atua_transport_document, tenant:, number: '74198', driver_code: 760, removed_from_atua_at: Time.current)
        create(:atua_transport_document, tenant: other_tenant, number: '74197', driver_code: 760)
      end

      scenario 'shows the driver with their vehicles and latest transport documents' do
        visit drivers_path
        click_on 'JOSE DA SILVA'

        expect(page).to have_current_path(driver_path(760))
        expect(page).to have_css('h1.page-title', text: 'JOSE DA SILVA')
        expect(dl_to_hash('#driver_data')).to eq(
          'Código do motorista' => '760',
          'Motorista' => 'JOSE DA SILVA',
          'CPF do motorista' => '808.542.250-64',
          'CNH' => '604269044',
          'Veículos' => '2',
        )
        expect(html_table_to_rows(table: find_by_id('driver_vehicles'))).to eq(
          [
            ['Placa', 'Categoria', 'Marca / Modelo', 'Propriedade'],
            ['BEV4G50', 'Carreta', '-', 'Terceiro'],
            ['EXU0F72', 'Caminhão / Cavalo', 'VOLVO FH 540', 'Próprio'],
          ],
        )
        expect(Atua::TransportDocument.count).to eq(5)
        expect(html_table_to_rows(table: find_by_id('driver_transport_documents'))).to eq(
          [
            ['Número', 'Emitido em', 'Origem / Destino', 'Placa', 'Frete'],
            ['74130', '02/10/2026 08:00', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 5.550,40'],
            ['74100', '28/09/2026 14:30', '- → -', 'EXU0F72', 'R$ 1.200,00'],
          ],
        )
      end

      scenario 'opens a vehicle of the driver' do
        visit driver_path(760)
        click_on 'BEV4G50'

        expect(page).to have_current_path(vehicle_path(trailer))
      end

      scenario 'opens a transport document of the driver' do
        visit driver_path(760)
        click_on '74130'

        expect(page).to have_current_path(transport_document_path(latest_document))
      end
    end

    context 'when a driver has more transport documents than the limit' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }

      before do
        11.times do |index|
          create(:atua_transport_document, tenant:, number: (74_100 + index).to_s, driver_code: 760,
                                           issued_at: Time.zone.local(2026, 10, 1) + index.days)
        end
      end

      scenario 'shows only the latest transport documents' do
        visit driver_path(760)

        rows = html_table_to_rows(table: find_by_id('driver_transport_documents'))
        expect(rows.size).to eq(DriversController::TRANSPORT_DOCUMENTS_LIMIT + 1)
        expect(rows.second.first).to eq('74110')
        expect(page).to have_no_css('#driver_transport_documents', text: '74100')
      end
    end

    context 'when a driver has no transport documents' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }

      scenario 'shows the empty state for the transport documents' do
        visit driver_path(760)

        expect(page).to have_css('#driver_vehicles')
        expect(page).to have_no_css('#driver_transport_documents')
        expect(page).to have_text('Nenhum registro encontrado')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA') }

    before { login_as(operator, scope: :user) }

    context 'without access to the drivers' do
      scenario 'is sent back with an access denied message' do
        visit drivers_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open a driver' do
        visit driver_path(760)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the drivers' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the drivers' do
        visit drivers_path

        expect(Atua::Vehicle.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on 'JOSE DA SILVA'

        expect(page).to have_current_path(driver_path(760))
      end

      context 'when the driver has a transport document' do
        let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', driver_code: 760) }

        scenario 'does not link the vehicles and transport documents without access to them' do
          visit driver_path(760)

          expect(page).to have_css('#driver_vehicles', text: 'EXU0F72')
          expect(page).to have_no_link('EXU0F72')
          expect(page).to have_css('#driver_transport_documents', text: transport_document.number)
          expect(page).to have_no_link('74130')
        end
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit drivers_path

      expect(page).to have_link('JOSE DA SILVA')
      expect(page).to have_no_css('th', text: 'CNH')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
