require 'rails_helper'

describe 'Empty legs' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Deslocamento vazio', slug: 'empty_legs', writable: false) }

  before { travel_to Time.zone.local(2026, 10, 20, 10) }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit empty_legs_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no empty legs' do
      scenario 'shows the empty state on both tables' do
        visit empty_legs_path

        expect(EmptyLeg.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado', count: 2)
        expect(page).to have_no_table
      end
    end

    context 'when there are empty legs' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: ['Cascavel']) }
      let!(:coamo) { create(:customer_group, tenant:, name: 'COAMO') }
      let!(:betim) do
        create(:location, lookup_key: 'RUA DAS FLORES 10|BETIM|MG', street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG',
                          precision_type: 'address')
      end
      let!(:ipatinga) { create(:location, lookup_key: '|IPATINGA|MG', city: 'IPATINGA', state: 'MG') }
      let!(:contagem) { create(:location, lookup_key: '|CONTAGEM|MG', city: 'CONTAGEM', state: 'MG') }
      let!(:cascavel) { create(:location, lookup_key: '|CASCAVEL|PR', city: 'CASCAVEL', state: 'PR') }
      let!(:loaded_in_vale) do
        create(:empty_leg, tenant:, plate: 'EXU0F72', previous_manifest_code: 41_100, next_manifest_code: 41_200, origin: betim,
                           destination: ipatinga, distance_km: BigDecimal('217.44'), precision_type: 'city')
      end
      let!(:stranger_leg) { create(:empty_leg, tenant: other_tenant, plate: 'EXU0F72', next_manifest_code: 41_600, distance_km: BigDecimal('999')) }

      before do
        create(:atua_manifest, tenant:, code: 41_100, number: '50100', plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 9, 25, 8))
        create(:atua_manifest, tenant:, code: 41_200, number: '50200', plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 3, 8))
        create(:atua_manifest, tenant:, code: 41_300, number: '50300', plate: 'QWE1A23', trip_started_at: nil, departure_on: Date.new(2026, 10, 15))
        create(:atua_manifest, tenant:, code: 41_400, number: '50400', plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 18, 6))
        create(:atua_manifest, tenant:, code: 41_500, number: '50500', plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 19, 6))
        create(:atua_manifest, tenant: other_tenant, code: 41_600, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 5))
        create(:atua_customer, tenant:, code: 7501, customer_group: coamo)
        create(:atua_transport_document, tenant:, code: 90_001, taker_code: 7501, origin_macro_region: vale_do_aco)
        create(:atua_transport_document, tenant:, code: 90_002, origin_macro_region: oeste_parana)

        loaded_in_parana = create(:empty_leg, tenant:, plate: 'QWE1A23', next_manifest_code: 41_300, origin: contagem, destination: cascavel,
                                              distance_km: BigDecimal('612.5'), precision_type: 'city')
        create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_400, origin: ipatinga, destination: contagem,
                           distance_km: BigDecimal('48.2'), precision_type: 'city')
        create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_500, origin: contagem, destination: nil,
                           status_type: 'unlocated', distance_km: nil, precision_type: nil)
        create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_100, distance_km: BigDecimal('300'))
        create(:empty_leg_transport_document, empty_leg: loaded_in_vale, transport_document_code: 90_001)
        create(:empty_leg_transport_document, empty_leg: loaded_in_parana, transport_document_code: 90_002)
      end

      scenario 'ranks the trips of the current month by the empty km and the loading regions' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Frota'
          click_on 'Deslocamento vazio'
        end

        expect(page).to have_current_path(empty_legs_path)
        expect(EmptyLeg.count).to eq(6)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['15/10/2026', 'QWE1A23', 'OESTE PARANA', '612,50 km', ''],
            ['03/10/2026', 'EXU0F72', 'VALE DO AÇO/MG', '217,44 km', ''],
            ['18/10/2026', 'EXU0F72', 'Outras', '48,20 km', ''],
          ],
        )
        expect(page).to have_text('3 registros')
        expect(html_table_to_rows(table: find_by_id('empty_leg_regions'))).to eq(
          [
            ['Região da carga', 'Viagens', 'Média de KM vazio', 'KM vazio total'],
            ['OESTE PARANA', '1', '612,50 km', '612,50 km'],
            ['VALE DO AÇO/MG', '1', '217,44 km', '217,44 km'],
            ['Outras', '1', '48,20 km', '48,20 km'],
          ],
        )
        within('#empty_legs_counters') do
          expect(page).to have_css('.counter-card', text: 'Viagens com KM vazio 3', normalize_ws: true)
          expect(page).to have_css('.counter-card', text: 'KM vazio total 878,14 km', normalize_ws: true)
          expect(page).to have_css('.counter-card', text: 'Média de KM vazio 292,71 km', normalize_ws: true)
          expect(page).to have_css('.counter-card', text: 'Viagens sem KM calculado 1', normalize_ws: true)
        end
      end

      scenario 'filters the trips through the filters modal' do
        visit empty_legs_path

        within('#filtersModal') do
          fill_in 'Viagens a partir de', with: '2026-09-01'
          fill_in 'Placa', with: 'exu-0f72'
          fill_in 'KM vazio mínimo', with: '200'
          click_on 'Aplicar Filtros'
        end

        expect(EmptyLeg.count).to eq(6)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['25/09/2026', 'EXU0F72', 'Outras', '300,00 km', ''],
            ['03/10/2026', 'EXU0F72', 'VALE DO AÇO/MG', '217,44 km', ''],
          ],
        )
        within('#empty_legs_counters') do
          expect(page).to have_css('.counter-card', text: 'KM vazio total 517,44 km', normalize_ws: true)
        end
      end

      scenario 'filters by the loading region and by the customer group' do
        visit empty_legs_path(macro_region_id: oeste_parana.id)

        expect(EmptyLeg.count).to eq(6)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['15/10/2026', 'QWE1A23', 'OESTE PARANA', '612,50 km', ''],
          ],
        )

        visit empty_legs_path(macro_region_id: MacroRegion::OTHERS)

        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['18/10/2026', 'EXU0F72', 'Outras', '48,20 km', ''],
          ],
        )

        visit empty_legs_path(customer_group_id: coamo.id)

        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['03/10/2026', 'EXU0F72', 'VALE DO AÇO/MG', '217,44 km', ''],
          ],
        )
        expect(html_table_to_rows(table: find_by_id('empty_leg_regions'))).to eq(
          [
            ['Região da carga', 'Viagens', 'Média de KM vazio', 'KM vazio total'],
            ['VALE DO AÇO/MG', '1', '217,44 km', '217,44 km'],
          ],
        )
      end

      scenario 'shows every period when the start date is cleared' do
        visit empty_legs_path(start_date: '', end_date: '2026-09-30')

        expect(EmptyLeg.count).to eq(6)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['25/09/2026', 'EXU0F72', 'Outras', '300,00 km', ''],
          ],
        )
      end

      scenario 'opens the details of a trip and goes back to the filtered listing' do
        visit empty_legs_path(plate: 'EXU0F72')

        expect(EmptyLeg.count).to eq(6)
        within("#empty_leg_#{loaded_in_vale.id}") { click_on 'Visualizar', match: :first }

        expect(page).to have_current_path(empty_leg_path(loaded_in_vale, return_to: empty_legs_path(plate: 'EXU0F72')))
        expect(page).to have_css('h1', text: 'Deslocamento vazio EXU0F72')
        expect(dl_to_hash('#empty_leg_trip')).to eq(
          'Dt. Viagem' => '03/10/2026', 'Placa' => loaded_in_vale.plate, 'Manifesto' => '50200', 'Viagem anterior' => '50100',
          'Região da carga' => 'VALE DO AÇO/MG'
        )
        expect(dl_to_hash('#empty_leg_data')).to eq(
          'Saída (última entrega)' => 'RUA DAS FLORES 10 - BETIM/MG', 'Chegada (coleta)' => 'IPATINGA/MG', 'KM vazio' => '217,44 km',
          'Precisão' => 'Centro da cidade', 'Situação' => 'Calculado', 'Calculado em' => I18n.l(loaded_in_vale.calculated_at, format: :date_time)
        )

        click_on 'Voltar para o deslocamento vazio'

        expect(page).to have_current_path(empty_legs_path(plate: 'EXU0F72'))
      end

      scenario 'does not open the empty leg of another tenant' do
        visit empty_leg_path(stranger_leg)

        expect(page.status_code).to eq(404)
      end

      scenario 'sorts the trips by the plate' do
        visit empty_legs_path
        within('#empty_legs') { click_on 'Placa' }

        expect(page).to have_current_path(empty_legs_path(sort: :plate, direction: :asc))
        expect(EmptyLeg.count).to eq(6)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['03/10/2026', 'EXU0F72', 'VALE DO AÇO/MG', '217,44 km', ''],
            ['18/10/2026', 'EXU0F72', 'Outras', '48,20 km', ''],
            ['15/10/2026', 'QWE1A23', 'OESTE PARANA', '612,50 km', ''],
          ],
        )
      end
    end

    context 'when there are more trips than a page' do
      before do
        11.times do |index|
          code = 42_000 + index
          create(:atua_manifest, tenant:, code:, number: (60_000 + index).to_s, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 2 + index))
          create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: code, distance_km: BigDecimal(100 + index))
        end
        create(:atua_manifest, tenant:, code: 43_000, plate: 'QWE1A23', trip_started_at: Time.zone.local(2026, 10, 2))
        create(:empty_leg, tenant:, plate: 'QWE1A23', next_manifest_code: 43_000, distance_km: BigDecimal('900'))
      end

      scenario 'keeps the filters when paging the trips' do
        visit empty_legs_path(plate: 'EXU0F72')

        expect(EmptyLeg.count).to eq(12)
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            *10.downto(1).map { |index| [format('%02d/10/2026', 2 + index), 'EXU0F72', 'Outras', "#{100 + index},00 km", ''] },
          ],
        )

        within('.table-pagination', match: :first) { click_on '2' }

        expect(page).to have_current_path(empty_legs_path(plate: 'EXU0F72', page: 2))
        expect(html_table_to_rows(table: find_by_id('empty_legs'))).to eq(
          [
            ['Dt. Viagem', 'Placa', 'Região da carga', 'KM vazio', 'Ações'],
            ['02/10/2026', 'EXU0F72', 'Outras', '100,00 km', ''],
          ],
        )
      end
    end

    context 'when the trips are exported to Excel', :xlsx_service do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }

      before do
        create(:atua_manifest, tenant:, code: 41_200, number: '50200', plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 3, 8))
        create(:atua_transport_document, tenant:, code: 90_001, origin_macro_region: vale_do_aco)
        leg = create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_200, distance_km: BigDecimal('217.44'), precision_type: 'city',
                                 origin: create(:location, city: 'BETIM', state: 'MG'), destination: create(:location, city: 'IPATINGA', state: 'MG'))
        create(:empty_leg_transport_document, empty_leg: leg, transport_document_code: 90_001)
      end

      scenario 'downloads the filtered trips with the loading region' do
        visit empty_legs_path

        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include("filename=\"deslocamento-vazio-#{Date.current.iso8601}.xlsx\"")
        expect(downloaded_xlsx_records).to eq(
          [
            {
              'Placa' => 'EXU0F72', 'De' => 'BETIM/MG', 'Para' => 'IPATINGA/MG', 'KM vazio' => 217.44, 'Precisão' => 'Centro da cidade',
              'Dt. Viagem' => Date.new(2026, 10, 3), 'Manifesto' => '50200', 'Região da carga' => 'VALE DO AÇO/MG'
            },
          ],
        )
      end
    end

    context 'when the screen is opened on a phone', :js do
      let!(:empty_leg) { create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_200, distance_km: BigDecimal('217.44')) }

      before do
        create(:atua_manifest, tenant:, code: 41_200, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 3, 8))
      end

      scenario 'keeps the date, the plate and the empty km and opens the details from the actions menu' do
        visit empty_legs_path
        use_mobile_screen

        expect(EmptyLeg.count).to eq(1)
        within('#empty_legs') do
          expect(page).to have_css('th', text: 'DT. VIAGEM')
          expect(page).to have_css('th', text: 'PLACA')
          expect(page).to have_css('th', text: 'KM VAZIO')
          expect(page).to have_no_css('th', text: 'REGIÃO DA CARGA')
        end
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

        within("#empty_leg_#{empty_leg.id}") { click_on 'Visualizar' }

        expect(page).to have_current_path(empty_leg_path(empty_leg, return_to: empty_legs_path))
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    scenario 'is sent back with an access denied message without the access' do
      visit empty_legs_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    context 'with read access to the empty legs' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'opens the screen from the fleet menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Frota'
          click_on 'Deslocamento vazio'
        end

        expect(page).to have_current_path(empty_legs_path)
      end
    end
  end
end
