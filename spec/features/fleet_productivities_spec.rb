require 'rails_helper'

describe 'Fleet productivity' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Produtividade de frota', slug: 'fleet_productivity', writable: false) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit fleet_productivity_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'without access to the fleet productivity' do
      scenario 'is sent back with an access denied message' do
        visit fleet_productivity_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the fleet productivity' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'opens the screen from the intelligence menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Inteligência'
          click_on 'Produtividade de frota'
        end

        expect(page).to have_current_path(fleet_productivity_path)
        expect(page).to have_css('h1', exact_text: 'Produtividade de frota')
        expect(page).to have_text('Nenhum registro encontrado', count: 2)
      end
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no empty legs' do
      scenario 'shows the empty state on both tables and no chart' do
        travel_to(Date.new(2026, 10, 19)) { visit fleet_productivity_path }

        expect(EmptyLeg.count).to eq(0)
        expect(page).to have_text('Viagens iniciadas de 18/10/2026 a 24/10/2026')
        expect(page).to have_text('Nenhum registro encontrado', count: 2)
        expect(page).to have_no_css('#fleet_productivity_routes_chart')
        expect(page).to have_no_table
      end
    end

    context 'when the trucks ran empty between located places' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:coamo) { create(:customer_group, tenant:, name: 'COAMO') }
      let!(:ipatinga) { create(:location, lookup_key: '|IPATINGA|MG', city: 'IPATINGA', state: 'MG') }
      let!(:belo_horizonte) { create(:location, lookup_key: '|BELO HORIZONTE|MG', city: 'BELO HORIZONTE', state: 'MG') }
      let!(:coamo_leg) do
        create(:empty_leg, tenant:, plate: 'RVR8J90', next_manifest_code: 41_002, origin: ipatinga, destination: belo_horizonte,
                           distance_km: BigDecimal('150'))
      end

      before do
        create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
        create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7))
        create(:atua_manifest, tenant:, code: 41_003, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 20, 6))
        create(:atua_manifest, tenant:, code: 41_004, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 9, 20, 6))
        create(:atua_manifest, tenant:, code: 41_005, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 25, 6))
        create(:atua_manifest, tenant: other_tenant, code: 41_001, plate: 'OUT1A11', trip_started_at: Time.zone.local(2026, 10, 2, 8))
        create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_001, origin: belo_horizonte, destination: ipatinga, distance_km: 80)
        create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_003, origin: ipatinga, destination: belo_horizonte, distance_km: 160)
        create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_004, origin: ipatinga, destination: belo_horizonte, distance_km: 999)
        create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_005, status_type: 'unrouted', origin: ipatinga, destination: belo_horizonte,
                           distance_km: nil)
        create(:empty_leg, tenant: other_tenant, plate: 'OUT1A11', next_manifest_code: 41_001, origin: ipatinga, destination: belo_horizonte,
                           distance_km: 777)
        create(:atua_customer, tenant:, code: 7501, customer_group: coamo)
        create(:atua_transport_document, tenant:, code: 90_001, taker_code: 7501)
        create(:empty_leg_transport_document, empty_leg: coamo_leg, transport_document_code: 90_001)
      end

      scenario 'ranks the routes and the unloading regions the trucks ran empty in the period' do
        visit fleet_productivity_path(october)

        expect(EmptyLeg.count).to eq(6)
        expect(page).to have_text('Viagens iniciadas de 01/10/2026 a 31/10/2026')
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Trechos vazios 3', 'KM vazio 390 km', 'KM vazio médio 130 km', 'Trechos não medidos 1'],
        )
        within('#fleet_productivity_routes_chart') do
          expect(page).to have_css('.chart-card-title', text: 'KM vazio por trecho')
        end
        expect(html_table_to_rows(table: find('#fleet_productivity_routes table'))).to eq(
          [
            ['Trecho', 'Trechos', 'KM médio', 'KM vazio'],
            ['IPATINGA/MG → BELO HORIZONTE/MG', '2', '155 km', '310 km'],
            ['BELO HORIZONTE/MG → IPATINGA/MG', '1', '80 km', '80 km'],
          ],
        )
        expect(html_table_to_rows(table: find('#fleet_productivity_regions table'))).to eq(
          [
            ['Região da descarga', 'Trechos', 'KM médio', 'KM vazio'],
            ['VALE DO AÇO/MG', '2', '155 km', '310 km'],
            ['Sem macro região', '1', '80 km', '80 km'],
          ],
        )
        expect(page).to have_no_text('999 km')
        expect(page).to have_no_text('777 km')
      end

      scenario 'filters the empty legs by the plate' do
        visit fleet_productivity_path(october.merge(plate: 'rvr8j90'))

        expect(html_table_to_rows(table: find('#fleet_productivity_routes table')).drop(1))
          .to eq([['IPATINGA/MG → BELO HORIZONTE/MG', '1', '150 km', '150 km']])
      end

      scenario 'filters the empty legs by the customer group of the next load' do
        visit fleet_productivity_path(october)
        within('#filtersModal') do
          select 'COAMO', from: 'Grupo de clientes da próxima carga'
          click_on 'Aplicar Filtros'
        end

        expect(first('.counter-card').text.squish).to eq('Trechos vazios 1')
        expect(html_table_to_rows(table: find('#fleet_productivity_routes table')).drop(1))
          .to eq([['IPATINGA/MG → BELO HORIZONTE/MG', '1', '150 km', '150 km']])
      end

      scenario 'rejects a period that ends before it starts' do
        visit fleet_productivity_path(start_date: '2026-10-31', end_date: '2026-10-01')

        expect(page).to have_current_path(fleet_productivity_path)
        expect(page).to have_text('Viagens até não pode ser anterior à data inicial')
      end

      scenario 'exports the empty routes and the unloading regions to their own sheets', :xlsx_service do
        visit fleet_productivity_path(october.merge(format: :xlsx))

        expect(downloaded_xlsx_sheet_names).to eq(['Trechos rodados vazios', 'Regiões da descarga'])
        expect(downloaded_xlsx_records(0)).to eq(
          [{ 'Trecho' => 'IPATINGA/MG → BELO HORIZONTE/MG', 'Trechos' => 2, 'KM médio' => 155, 'KM vazio' => 310 },
           { 'Trecho' => 'BELO HORIZONTE/MG → IPATINGA/MG', 'Trechos' => 1, 'KM médio' => 80, 'KM vazio' => 80 }],
        )
        expect(downloaded_xlsx_records(1)).to eq(
          [{ 'Região da descarga' => 'VALE DO AÇO/MG', 'Trechos' => 2, 'KM médio' => 155, 'KM vazio' => 310 },
           { 'Região da descarga' => 'Sem macro região', 'Trechos' => 1, 'KM médio' => 80, 'KM vazio' => 80 }],
        )
      end

      scenario 'pages each table on its own keeping the filters', :js do
        26.times do |index|
          location = create(:location, lookup_key: "|CIDADE #{index}|SP", city: "CIDADE #{index}", state: 'SP')
          create(:atua_manifest, tenant:, code: 50_000 + index, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 21, 6) + index.minutes)
          create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 50_000 + index, origin: location, destination: ipatinga, distance_km: 10 + index)
        end

        visit fleet_productivity_path(october)
        within('#fleet_productivity_routes .table-pagination') { click_on '3' }

        expect(page).to have_current_path(fleet_productivity_path(october.merge(empty_routes_page: 3)))
        expect(html_table_to_rows(table: find('#fleet_productivity_routes table')).drop(1).map(&:first))
          .to eq((0..7).reverse_each.map { |index| "CIDADE #{index}/SP → IPATINGA/MG" })
        expect(html_table_to_rows(table: find('#fleet_productivity_regions table')).drop(1).map(&:first))
          .to eq(['Sem macro região', 'VALE DO AÇO/MG'])
      end

      scenario 'keeps the tables inside a phone screen', :js do
        use_mobile_screen(width: 360)
        visit fleet_productivity_path(october)

        within('#fleet_productivity_routes') do
          expect(page).to have_css('td', text: 'IPATINGA/MG → BELO HORIZONTE/MG')
          expect(page).to have_no_css('th', text: 'KM médio')
        end
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end
end
