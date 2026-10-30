require 'rails_helper'

describe 'Freight billing' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit freight_billing_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when the Atua reports were never synced' do
      let!(:failed_import) { create(:atua_import, tenant:, status_type: :failed, finished_at: Time.zone.local(2026, 10, 28, 9)) }

      scenario 'warns that there was no sync with Atua yet' do
        visit freight_billing_path(october)

        expect(Atua::Import.count).to eq(1)
        expect(page).to have_css('.page-header .page-note', text: 'Nenhuma sincronização com a Atua até o momento')
      end
    end

    context 'when the Atua reports were synced' do
      before do
        create(:atua_import, tenant:, status_type: :succeeded, finished_at: Time.zone.local(2026, 10, 27, 8, 15))
        create(:atua_import, tenant:, report_type: 'manifests', status_type: :succeeded, finished_at: Time.zone.local(2026, 10, 28, 14, 32))
        create(:atua_import, tenant:, status_type: :failed, finished_at: Time.zone.local(2026, 10, 29, 7))
        create(:atua_import, tenant: other_tenant, status_type: :succeeded, finished_at: Time.zone.local(2026, 10, 29, 10))
      end

      scenario 'shows the date of the last successful sync of the tenant' do
        visit freight_billing_path(october)

        expect(Atua::Import.count).to eq(4)
        expect(find('.page-header .page-note').text).to eq('Última sincronização com a Atua: 28/10/2026 14:32')
      end
    end

    context 'when there are no trips in the period' do
      scenario 'shows the empty state with zeroed indicators' do
        visit freight_billing_path(october)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 0,00', 'Frete bruto com MDF-e R$ 0,00', 'Frete bruto sem MDF-e R$ 0,00', 'Frete líquido R$ 0,00',
           'Viagens 0', 'Frete bruto por km -', 'Frete líquido por km -', 'KM rodado 0 km'],
        )
      end
    end

    context 'when there are trips and complements' do
      def ranking_bar_labels
        expect(page).to have_css('.chart-card canvas', count: 2)

        page.document.synchronize do
          page.evaluate_script(
            '(Object.values(Chartkick.charts)[0].getChartObject().$datalabels?._labels || [])' \
            '.filter((label) => label.$layout?._visible)' \
            '.map((label) => [label._model.lines.join(" "), label._model.color])',
          ).presence || raise(Capybara::ExpectationNotMet)
        end
      end

      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:grouped_taker) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
      let!(:loose_taker) { create(:atua_customer, tenant:, code: 7200) }
      let!(:first_trip) { create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8)) }
      let!(:second_trip) { create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7)) }
      let!(:steel) do
        create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000, weight_freight_cents: 900_000,
                                         toll_cents: 25_000, icms_cents: 75_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02', driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7100, origin_city: 'IPATINGA',
                                         origin_state: 'MG')
      end
      let!(:coil) do
        create(:atua_transport_document, tenant:, number: '74002', freight_cents: 500_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02',
                                         driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7200, origin_city: 'IPATINGA',
                                         origin_state: 'MG')
      end
      let!(:sheet) do
        create(:atua_transport_document, tenant:, number: '74003', freight_cents: 400_000, plate: 'RVR8J90', driver_code: 20,
                                         driver_name: 'MARIA SOUZA', taker_code: 7100, origin_city: 'BELO HORIZONTE', origin_state: 'MG')
      end
      let!(:complement) do
        create(:atua_transport_document, tenant:, number: '3547', document_kind: 'ce', freight_cents: 100_000,
                                         posted_on: Date.new(2026, 10, 15), plate: 'RVR8J90', driver_code: 20, driver_name: 'MARIA SOUZA',
                                         taker_code: 7100, origin_city: 'BELO HORIZONTE', origin_state: 'MG')
      end
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74001', freight_cents: 5_000_000) }

      before do
        create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001',
                                        calculated_distance_km: 500, document_distance_km: 480)
        create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74002',
                                        calculated_distance_km: 300, document_distance_km: 520)
        create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74003', calculated_distance_km: 200)
        create(:empty_leg, tenant:, plate: 'RVR2C34', previous_manifest_code: 40_999, next_manifest_code: 41_001, distance_km: 80)
        create(:freight_expense, tenant:, transport_document: steel, amount_cents: 20_000)
        create(:freight_expense, :tonnage, tenant:, transport_document: steel, amount_cents: 30_000)
        create(:atua_expense, tenant:, cost_object: steel, history_code: 72, total_cents: 15_000)
        create(:atua_manifest, tenant: other_tenant, code: 41_001, plate: 'OUT1A11', trip_started_at: Time.zone.local(2026, 10, 2))
        create(:atua_manifest_document, tenant: other_tenant, manifest_code: 41_001, transport_document_number: '74001',
                                        calculated_distance_km: 50)
      end

      scenario 'opens the current week from sunday to saturday from the intelligence menu' do
        travel_to(Date.new(2026, 10, 19)) do
          visit root_path
          within('.sidebar-desktop') do
            click_on 'Inteligência'
            click_on 'Faturamento de Fretes'
          end

          expect(page).to have_current_path(freight_billing_path)
          expect(page).to have_css('h1', text: 'Faturamento de Fretes')
          expect(page).to have_text('Saídas de 18/10/2026 a 24/10/2026')
          expect(page).to have_field('Saídas a partir de', with: '2026-10-18', visible: :all)
          expect(page).to have_field('Saídas até', with: '2026-10-24', visible: :all)
          expect(page).to have_link('Cavalo', class: 'btn-primary')
        end
      end

      scenario 'shows the gross and net freight per truck discounting the toll inside the gross freight' do
        visit freight_billing_path(october)

        expect(Atua::TransportDocument.count).to eq(5)
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 20.000,00', 'Frete bruto com MDF-e R$ 20.000,00', 'Frete bruto sem MDF-e R$ 0,00',
           'Frete líquido R$ 19.100,00', 'Viagens 2', 'Frete bruto por km R$ 26,39', 'Frete líquido por km R$ 25,14',
           'KM rodado 720 km'],
        )
        expect(page).to have_text('Frete por Cavalo')
        expect(page).to have_text('Evolução Mensal')
        expect(page).to have_text('Frete bruto e líquido por mês de emissão do CT-e, de Mai/2026 a Out/2026')
        expect(html_table_to_rows).to eq(
          [
            ['Cavalo', 'Viagens', 'KM rodado', 'Frete bruto', 'Despesas de frete', 'Despesas', 'Pedágio', 'Frete líquido',
             'Bruto/km', 'Líquido/km', 'Participação'],
            ['RVR2C34', '1', '520 km', 'R$ 15.000,00', 'R$ 500,00', 'R$ 150,00', 'R$ 250,00', 'R$ 14.100,00',
             'R$ 28,85', 'R$ 27,12', '75,0%'],
            ['RVR8J90', '1', '200 km', 'R$ 5.000,00', 'R$ 0,00', 'R$ 0,00', 'R$ 0,00', 'R$ 5.000,00', 'R$ 20,00', 'R$ 20,00',
             '25,0%'],
            ['Total', '2', '720 km', 'R$ 20.000,00', 'R$ 500,00', 'R$ 150,00', 'R$ 250,00', 'R$ 19.100,00', 'R$ 26,39',
             'R$ 25,14', '100,0%'],
          ],
        )
        expect(page).to have_no_text('OUT1A11')
      end

      context 'when a truck billed too little to hold its value inside the bar' do
        before do
          create(:atua_manifest, tenant:, code: 41_010, plate: 'RVR1A11', trip_started_at: Time.zone.local(2026, 10, 12, 7))
          create(:atua_transport_document, tenant:, number: '74010', freight_cents: 30_000, plate: 'RVR1A11', driver_code: 30,
                                           driver_name: 'PAULO DIAS')
          create(:atua_manifest_document, tenant:, manifest_code: 41_010, transport_document_number: '74010', calculated_distance_km: 50)
        end

        scenario 'writes the value inside the bars that hold it and beside the short ones in the color of the bar', :js do
          visit freight_billing_path(october)

          expect(Atua::TransportDocument.count).to eq(6)
          expect(ranking_bar_labels).to contain_exactly(
            ['R$ 15.000,00', '#ffffff'], ['R$ 5.000,00', '#ffffff'], ['R$ 300,00', '#2563eb'],
            ['R$ 14.100,00', '#ffffff'], ['R$ 5.000,00', '#ffffff'], ['R$ 300,00', '#eb6834']
          )
        end

        context 'when the ranking lists fifteen trucks' do
          before do
            12.times do |index|
              plate = "RVR3B#{index.to_s.rjust(2, '0')}"
              number = (75_000 + index).to_s
              create(:atua_manifest, tenant:, code: 42_000 + index, plate:, trip_started_at: Time.zone.local(2026, 10, 12, 7))
              document = create(:atua_transport_document, tenant:, number:, freight_cents: 250_000 - (index * 10_000), plate:)
              create(:freight_expense, tenant:, transport_document: document, amount_cents: 200_000 - (index * 10_000))
              create(:atua_manifest_document, tenant:, manifest_code: 42_000 + index, transport_document_number: number,
                                              calculated_distance_km: 50)
            end
          end

          scenario 'writes the net freight of every truck even when its value sits beside a short bar', :js do
            visit freight_billing_path(october)

            expect(Atua::TransportDocument.count).to eq(18)
            expect(ranking_bar_labels.size).to eq(30)
            expect(ranking_bar_labels).to include(['R$ 14.100,00', '#ffffff'], ['R$ 2.500,00', '#ffffff'])
            expect(ranking_bar_labels.count(['R$ 500,00', '#eb6834'])).to eq(12)
          end
        end
      end

      scenario 'groups the freight by driver keeping the period' do
        visit freight_billing_path(october)
        click_on 'Motorista'

        expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'driver')))
        expect(page).to have_link('Motorista', class: 'btn-primary')
        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 3, 7) }).to eq(
          [
            ['Motorista', 'Viagens', 'Frete bruto', 'Frete líquido'],
            ['JOSE SILVA', '1', 'R$ 15.000,00', 'R$ 14.100,00'],
            ['MARIA SOUZA', '1', 'R$ 5.000,00', 'R$ 5.000,00'],
            ['Total', '2', 'R$ 20.000,00', 'R$ 19.100,00'],
          ],
        )
      end

      scenario 'splits a shared trip between the customer groups by their share of its freight' do
        visit freight_billing_path(october.merge(dimension: 'customer_group'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2, 3) }).to eq(
          [
            ['Grupo de clientes', 'Viagens', 'KM rodado', 'Frete bruto'],
            ['USIMINAS', '1,7', '547 km', 'R$ 15.000,00'],
            ['Sem grupo', '0,3', '173 km', 'R$ 5.000,00'],
            ['Total', '2', '720 km', 'R$ 20.000,00'],
          ],
        )
      end

      scenario 'groups the freight by origin' do
        visit freight_billing_path(october.merge(dimension: 'origin'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 3, 10) }).to eq(
          [
            ['Origem', 'Frete bruto', 'Participação'],
            ['IPATINGA/MG', 'R$ 15.000,00', '75,0%'],
            ['BELO HORIZONTE/MG', 'R$ 5.000,00', '25,0%'],
            ['Total', 'R$ 20.000,00', '100,0%'],
          ],
        )
      end

      context 'when the origins belong to macro regions' do
        let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH', state: 'MG', cities: ['Belo Horizonte', 'Betim']) }

        before { MacroRegions::AssignCommand.call(tenant) }

        scenario 'groups the freight by the macro region of the origin with the other origins apart' do
          visit freight_billing_path(october)
          click_on 'Macro região'

          expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'macro_region')))
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 3, 10) }).to eq(
            [
              ['Macro região', 'Viagens', 'Frete bruto', 'Participação'],
              ['Outras Regiões', '1', 'R$ 15.000,00', '75,0%'],
              ['GRANDE BH', '1', 'R$ 5.000,00', '25,0%'],
              ['Total', '2', 'R$ 20.000,00', '100,0%'],
            ],
          )
        end

        scenario 'filters by a macro region of origin' do
          visit freight_billing_path(october)
          select 'GRANDE BH', from: 'Macro região de origem'
          click_on 'Aplicar Filtros'

          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')
          expect(page).to have_select('Macro região de origem', selected: 'GRANDE BH', visible: :all)
        end

        scenario 'filters by the origins out of every macro region' do
          visit freight_billing_path(october)
          select 'Outras Regiões', from: 'Macro região de origem'
          click_on 'Aplicar Filtros'

          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 15.000,00')
        end
      end

      scenario 'filters by plate and customer group' do
        visit freight_billing_path(october.merge(customer_group_id: usiminas.id))
        fill_in 'Placa', with: 'rvr-8j90'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
        expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')
      end

      context 'when there are documents linked to no trip' do
        let!(:pickup) { create(:atua_transport_document, tenant:, number: '74899', freight_cents: 60_000, posted_on: Date.new(2026, 10, 26)) }
        let!(:transfer) { create(:atua_transport_document, tenant:, number: '74903', freight_cents: 26_900, posted_on: Date.new(2026, 10, 26)) }
        let!(:november) do
          create(:atua_transport_document, tenant:, number: '74950', freight_cents: 90_000, issued_at: Time.zone.local(2026, 11, 2, 8),
                                           posted_on: Date.new(2026, 11, 2))
        end
        let!(:canceled) do
          create(:atua_transport_document, tenant:, number: '74951', freight_cents: 70_000, posted_on: Date.new(2026, 10, 26),
                                           canceled_at: Time.zone.local(2026, 10, 26, 18))
        end

        scenario 'adds the freight of the documents without a trip to the gross freight like the Atua report' do
          visit freight_billing_path(october)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(8)
          expect(all('.counter-card').first(4).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.869,00', 'Frete bruto com MDF-e R$ 20.000,00', 'Frete bruto sem MDF-e R$ 869,00',
             'Frete líquido R$ 19.969,00'],
          )
        end
      end

      context 'when a transport document is issued in the month before its trip departs' do
        let!(:previous_month) do
          create(:atua_transport_document, tenant:, number: '74103', freight_cents: 607_332, plate: 'RHJ5A50',
                                           issued_at: Time.zone.local(2026, 9, 30, 18, 1), posted_on: Date.new(2026, 9, 30))
        end

        before do
          create(:atua_manifest, tenant:, code: 41_010, plate: 'RHJ5A50', trip_started_at: Time.zone.local(2026, 10, 2, 9))
          create(:atua_manifest_document, tenant:, manifest_code: 41_010, transport_document_number: '74103', calculated_distance_km: 400)
        end

        scenario 'bills its freight in the month of the issue like the Atua report and keeps the trip in the month it departed' do
          visit freight_billing_path(october)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(5)
          expect(all('.counter-card').first(5).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.000,00', 'Frete bruto com MDF-e R$ 20.000,00', 'Frete bruto sem MDF-e R$ 0,00',
             'Frete líquido R$ 19.100,00', 'Viagens 3'],
          )
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 3) }).to include(['RHJ5A50', '1', 'R$ 6.073,32'])

          visit freight_billing_path(start_date: '2026-09-01', end_date: '2026-09-30')

          expect(all('.counter-card').first(5).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 6.073,32', 'Frete bruto com MDF-e R$ 6.073,32', 'Frete bruto sem MDF-e R$ 0,00',
             'Frete líquido R$ 6.073,32', 'Viagens 0'],
          )
        end
      end

      context 'when some issuers of the Atua are excluded' do
        let!(:maycon) { create(:excluded_issuer, tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA') }
        let!(:stranger_exclusion) { create(:excluded_issuer, tenant: other_tenant, code: 6001, name: 'EMISSAO CTE') }
        let!(:abroad) do
          create(:atua_transport_document, tenant:, number: '4267', document_kind: 'ce', issuer_code: 6190, freight_cents: 1_657_920,
                                           issued_at: Time.zone.local(2026, 10, 2, 10), posted_on: Date.new(2026, 10, 2), plate: 'RVR8J90',
                                           taker_code: 7100)
        end
        let!(:loose) do
          create(:atua_transport_document, tenant:, number: '74899', issuer_code: 6190, freight_cents: 60_000,
                                           posted_on: Date.new(2026, 10, 26))
        end
        let!(:boarded) do
          create(:atua_transport_document, tenant:, number: '74004', issuer_code: 6190, freight_cents: 300_000, plate: 'RVR8J90',
                                           taker_code: 7100)
        end

        before do
          coil.update!(issuer_code: 6001)
          create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74004', calculated_distance_km: 200)
        end

        scenario 'leaves the documents of the excluded issuers out of the gross and the net freight' do
          visit freight_billing_path(october)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(7)
          expect(all('.counter-card').map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.000,00', 'Frete bruto com MDF-e R$ 20.000,00', 'Frete bruto sem MDF-e R$ 0,00',
             'Frete líquido R$ 19.100,00', 'Viagens 2', 'Frete bruto por km R$ 26,39', 'Frete líquido por km R$ 25,14',
             'KM rodado 720 km'],
          )
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 3, 7) }).to eq(
            [
              ['Cavalo', 'Viagens', 'Frete bruto', 'Frete líquido'],
              ['RVR2C34', '1', 'R$ 15.000,00', 'R$ 14.100,00'],
              ['RVR8J90', '1', 'R$ 5.000,00', 'R$ 5.000,00'],
              ['Total', '2', 'R$ 20.000,00', 'R$ 19.100,00'],
            ],
          )
        end

        scenario 'leaves the documents of the excluded issuers out of the customer groups' do
          visit freight_billing_path(october.merge(dimension: 'customer_group'))

          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2, 3) }).to eq(
            [
              ['Grupo de clientes', 'Viagens', 'KM rodado', 'Frete bruto'],
              ['USIMINAS', '1,7', '547 km', 'R$ 15.000,00'],
              ['Sem grupo', '0,3', '173 km', 'R$ 5.000,00'],
              ['Total', '2', '720 km', 'R$ 20.000,00'],
            ],
          )
        end

        scenario 'counts the documents of an issuer again once it is considered' do
          maycon.destroy!

          visit freight_billing_path(october)

          expect(all('.counter-card').first(4).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 40.179,20', 'Frete bruto com MDF-e R$ 39.579,20', 'Frete bruto sem MDF-e R$ 600,00',
             'Frete líquido R$ 39.279,20'],
          )
        end
      end

      context 'when the trucks haul sets with different axle counts' do
        let!(:rodotrem) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }
        let!(:ls) { create(:truck_group, :ls, tenant:) }

        before do
          create(:truck_group, tenant:, name: 'Quarto eixo', axles: [7])
          create(:truck_group, tenant:, name: 'Bitrem antigo', axles: [6], activated_at: nil)
          create(:truck_group, tenant: other_tenant, name: 'Grupo de outra', axles: [3])
          steel.update!(axles: 9)
          coil.update!(axles: 9)
          sheet.update!(axles: 3)
        end

        scenario 'filters by the active truck groups of the tenant' do
          visit freight_billing_path(october)

          expect(TruckGroup.count).to eq(5)
          expect(page).to have_select('Tipo de conjunto', options: ['Todos', 'LS', 'Quarto eixo', 'Rodotrem', 'Sem grupo'])

          select 'Rodotrem', from: 'Tipo de conjunto'
          click_on 'Aplicar Filtros'

          expect(page).to have_select('Tipo de conjunto', selected: 'Rodotrem')
          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 15.000,00')

          select 'Sem grupo', from: 'Tipo de conjunto'
          click_on 'Aplicar Filtros'

          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')

          select 'LS', from: 'Tipo de conjunto'
          click_on 'Aplicar Filtros'

          expect(page).to have_text('Nenhum registro encontrado')
        end

        scenario 'keeps the truck group when grouping by another dimension' do
          visit freight_billing_path(october.merge(truck_group_id: rodotrem.id))
          click_on 'Motorista'

          expect(page).to have_current_path(freight_billing_path(october.merge(truck_group_id: rodotrem.id, dimension: 'driver')))
          expect(html_table_to_rows.map(&:first)).to eq(['Motorista', 'JOSE SILVA', 'Total'])
        end

        scenario 'finds nothing for a truck group of another tenant' do
          visit freight_billing_path(october.merge(truck_group_id: TruckGroup.find_by!(name: 'Grupo de outra').id))

          expect(page).to have_text('Nenhum registro encontrado')
        end

        context 'with a group of the remaining axles' do
          let!(:others) { create(:truck_group, :others, tenant:) }

          scenario 'lists the group instead of the transport documents without group' do
            visit freight_billing_path(october)

            expect(TruckGroup.count).to eq(6)
            expect(page).to have_select('Tipo de conjunto', options: ['Todos', 'LS', 'Outros', 'Quarto eixo', 'Rodotrem'])
            expect(page).to have_text('Pela quantidade de eixos informada em cada CT-e.')

            select 'Outros', from: 'Tipo de conjunto'
            click_on 'Aplicar Filtros'

            expect(page).to have_select('Tipo de conjunto', selected: 'Outros')
            expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')
          end
        end

        context 'when a truck hauls sets with another axle count' do
          before { coil.update!(axles: 6) }

          scenario 'filters each transport document by its own axle count' do
            visit freight_billing_path(october.merge(truck_group_id: ls.id))

            expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')

            visit freight_billing_path(october.merge(truck_group_id: rodotrem.id))

            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 10.000,00')
          end
        end

        scenario 'rejects an unknown truck group' do
          visit freight_billing_path(october.merge(truck_group_id: 'rodotrem'))

          expect(page).to have_current_path(freight_billing_path)
          expect(page).to have_text('Tipo de conjunto não é válido')
        end
      end

      scenario 'filters by another period' do
        visit freight_billing_path(october)
        fill_in 'Saídas a partir de', with: '2026-10-05'
        fill_in 'Saídas até', with: '2026-10-31'
        click_on 'Aplicar Filtros'

        expect(page).to have_text('Saídas de 05/10/2026 a 31/10/2026')
        expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
      end

      scenario 'keeps the period fields inside the filters modal and the shortcuts outside it' do
        visit freight_billing_path(october)

        expect(page).to have_css('#filtersModal input[type="date"]', count: 2, visible: :all)
        expect(page).to have_link('Hoje')
        expect(page).to have_no_css('#filtersModal a', text: 'Hoje', visible: :all)
      end

      scenario 'switches the period through the shortcuts highlighting the selected one' do
        travel_to(Date.new(2026, 10, 19)) do
          visit freight_billing_path

          expect(page).to have_link('Essa semana', class: 'btn-primary')
          expect(page).to have_link('Esse mês', class: 'btn-outline-secondary')

          click_on 'Esse mês'

          expect(page).to have_text('Saídas de 01/10/2026 a 31/10/2026')
          expect(page).to have_field('Saídas a partir de', with: '2026-10-01')
          expect(page).to have_field('Saídas até', with: '2026-10-31')
          expect(page).to have_link('Esse mês', class: 'btn-primary')
          expect(page).to have_link('Essa semana', class: 'btn-outline-secondary')

          click_on 'Hoje'

          expect(page).to have_text('Saídas de 19/10/2026 a 19/10/2026')
          expect(page).to have_link('Hoje', class: 'btn-primary')

          click_on 'Essa semana'

          expect(page).to have_text('Saídas de 18/10/2026 a 24/10/2026')
          expect(page).to have_link('Essa semana', class: 'btn-primary')
        end
      end

      scenario 'highlights no shortcut on a custom period' do
        visit freight_billing_path(start_date: '2026-10-05', end_date: '2026-10-06')

        expect(page).to have_text('Saídas de 05/10/2026 a 06/10/2026')
        expect(page).to have_no_css('a.btn-primary', text: /\A(Essa semana|Esse mês|Hoje)\z/)
      end

      scenario 'keeps the other filters and the grouping when choosing a shortcut' do
        travel_to(Date.new(2026, 10, 19)) do
          visit freight_billing_path(october.merge(dimension: 'driver', plate: 'RVR8J90'))
          click_on 'Hoje'

          expect(page).to have_text('Saídas de 19/10/2026 a 19/10/2026')
          expect(Rack::Utils.parse_query(URI(page.current_url).query)).to eq('dimension' => 'driver', 'plate' => 'RVR8J90',
                                                                             'start_date' => '2026-10-19', 'end_date' => '2026-10-19')
        end
      end

      context 'when the trucks spent diesel and arla in the last twelve months' do
        let!(:rented_trip) do
          create(:atua_manifest, tenant:, code: 41_003, plate: 'PUR1A81', trip_started_at: Time.zone.local(2026, 10, 12, 8))
        end
        let!(:rented) do
          create(:atua_transport_document, tenant:, number: '74004', freight_cents: 300_000, plate: 'PUR1A81',
                                           vehicle_ownership: 'Terceiro')
        end

        before do
          create(:atua_manifest_document, tenant:, manifest_code: 41_003, transport_document_number: '74004', calculated_distance_km: 150)
          create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 11, document_on: Date.new(2026, 9, 20), total_cents: 150_000)
          create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 396, document_on: Date.new(2026, 10, 3), total_cents: 30_000)
          create(:atua_expense, tenant:, plate: 'RVR2C34', history_code: 56, document_on: Date.new(2026, 10, 3), total_cents: 40_000)
          create(:atua_expense, tenant:, plate: 'RVR8J90', history_code: 11, document_on: Date.new(2025, 10, 31), total_cents: 90_000)
          create(:atua_expense, tenant:, plate: 'PUR1A81', history_code: 11, document_on: Date.new(2026, 10, 12), total_cents: 60_000)
        end

        scenario 'does not discount the fuel from the net freight' do
          visit freight_billing_path(october)

          expect(Atua::Expense.count).to eq(6)
          expect(page).to have_no_text('Combustível')
          expect(html_table_to_rows.map { |row| row.values_at(0, 2, 3, 7) }).to eq(
            [
              ['Cavalo', 'KM rodado', 'Frete bruto', 'Frete líquido'],
              ['RVR2C34', '520 km', 'R$ 15.000,00', 'R$ 14.100,00'],
              ['RVR8J90', '200 km', 'R$ 5.000,00', 'R$ 5.000,00'],
              ['PUR1A81', '150 km', 'R$ 3.000,00', 'R$ 3.000,00'],
              ['Total', '870 km', 'R$ 23.000,00', 'R$ 22.100,00'],
            ],
          )
          expect(all('.counter-card')[3].text.squish).to eq('Frete líquido R$ 22.100,00')
        end
      end

      context 'when the empty km of a trip could not be calculated' do
        before do
          create(:empty_leg, tenant:, plate: 'RVR8J90', previous_manifest_code: 41_000, next_manifest_code: 41_002,
                             status_type: 'unrouted', distance_km: nil)
        end

        scenario 'measures every trip by its loaded km without warning about the empty km' do
          visit freight_billing_path(october)

          expect(EmptyLeg.count).to eq(2)
          expect(page).to have_no_text('KM vazio')
          expect(all('.counter-card').last.text.squish).to eq('KM rodado 720 km')
        end
      end

      scenario 'rejects a period that ends before it starts' do
        visit freight_billing_path(start_date: '2026-10-31', end_date: '2026-10-01')

        expect(page).to have_current_path(freight_billing_path)
        expect(page).to have_text('Saídas até não pode ser anterior à data inicial')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'without access to the freight billing' do
      scenario 'is sent back with an access denied message' do
        visit freight_billing_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the freight billing' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'opens the freight billing' do
        visit freight_billing_path(october)

        expect(page).to have_css('h1', text: 'Faturamento de Fretes')
        expect(page).to have_text('Nenhum registro encontrado')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
      create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02')
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001', calculated_distance_km: 500)
      login_as(admin, scope: :user)
    end

    scenario 'draws both charts and keeps only the essential columns without scrolling sideways' do
      use_mobile_screen
      visit freight_billing_path(october)

      expect(page).to have_css('canvas', count: 2)
      expect(page).to have_css('th', text: /\AFrete líquido\z/i)
      expect(page).to have_no_css('th', text: /\AKM rodado\z/i)
      expect(page).to have_no_css('th', text: /\APedágio\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the indicators two per row and the grouping options in a single swipeable line' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      card_tops = page.evaluate_script("[...document.querySelectorAll('.counter-card')].map((card) => card.getBoundingClientRect().top)")
      option_tops = page.evaluate_script("[...document.querySelectorAll('.dashboard-segmented .btn')].map((option) => option.getBoundingClientRect().top)")
      title_top = page.evaluate_script("document.querySelector('.page-title').getBoundingClientRect().top")
      filter_top = page.evaluate_script("document.querySelector('.page-actions').getBoundingClientRect().top")

      expect(card_tops.each_slice(2).map { |pair| pair.uniq.size }).to eq([1, 1, 1, 1])
      expect(card_tops.uniq.size).to eq(4)
      expect(option_tops.uniq.size).to eq(1)
      expect(filter_top).to be <= title_top
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the period shortcuts without opening the modal or scrolling sideways' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      expect(page).to have_link('Essa semana')
      expect(page).to have_link('Esse mês')
      expect(page).to have_link('Hoje')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when filtering by customer group and driver', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:atua_customer, tenant:, code: 7100, customer_group: create(:customer_group, tenant:, name: 'USIMINAS'))
      create(:atua_customer, tenant:, code: 7200, customer_group: create(:customer_group, tenant:, name: 'GERDAU'))
      create(:atua_customer, tenant: other_tenant, code: 7400, customer_group: create(:customer_group, tenant: other_tenant, name: 'GRUPO DE OUTRA'))
      create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
      create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7))
      create(:atua_manifest, tenant:, code: 41_003, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 20, 7))
      create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000, plate: 'RVR2C34', driver_code: 10,
                                       driver_name: 'JOSE CARLOS DA SILVA', taker_code: 7100)
      create(:atua_transport_document, tenant:, number: '74002', freight_cents: 400_000, plate: 'RVR8J90', driver_code: 20,
                                       driver_name: 'MARIA SOUZA', taker_code: 7100)
      create(:atua_transport_document, tenant:, number: '74003', freight_cents: 300_000, plate: 'RVR8J90', driver_code: 20,
                                       driver_name: 'MARIA SOUZA', taker_code: 7200)
      create(:atua_transport_document, tenant: other_tenant, number: '74004', freight_cents: 900_000, driver_code: 30,
                                       driver_name: 'MOTORISTA DE OUTRA', taker_code: 7400)
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001', calculated_distance_km: 500)
      create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74002', calculated_distance_km: 200)
      create(:atua_manifest_document, tenant:, manifest_code: 41_003, transport_document_number: '74003', calculated_distance_km: 100)
      login_as(admin, scope: :user)
    end

    scenario 'searches the customer groups and the drivers of the tenant and filters the freight by them on a phone' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)
      find(:link, href: '#filtersModal').click

      within('#customer_group_id_select') do
        find('.select2-trigger').click
        expect(all('.select2-option').map(&:text)).to eq(%w[GERDAU USIMINAS])

        find('.select2-search').fill_in(with: 'usi')
        find('.select2-option', text: 'USIMINAS').click
      end

      within('#driver_code_select') do
        find('.select2-trigger').click
        expect(all('.select2-option').map(&:text)).to eq(['JOSE CARLOS DA SILVA', 'MARIA SOUZA'])

        find('.select2-option', text: 'MARIA SOUZA').click
      end

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      click_on 'Aplicar Filtros'

      expect(Atua::TransportDocument.where(tenant:).count).to eq(3)
      expect(page).to have_current_path(/customer_group_id=\d+&driver_code=20/)
      expect(first('.counter-value')).to have_text('R$ 4.000,00')
      expect(page).to have_css('#customer_group_id_select .select2-single-value', text: 'USIMINAS', visible: :all)
      expect(page).to have_css('#driver_code_select .select2-single-value', text: 'MARIA SOUZA', visible: :all)
    end
  end

  context 'when the freight reaches hundreds of thousands on a laptop screen beside the sidebar', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
      create(:atua_transport_document, tenant:, number: '74002', freight_cents: 74_687_244, plate: 'RVR2C34', trailer_plate: 'RVR9C02')
      create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74002', calculated_distance_km: 53_117)
      login_as(admin, scope: :user)
    end

    scenario 'keeps every indicator value inside its card' do
      page.driver.resize(1346, 900)
      visit freight_billing_path(october)

      overflowing = page.evaluate_script(
        "[...document.querySelectorAll('.counter-value')].filter((value) => value.scrollWidth > value.parentElement.clientWidth).length",
      )

      expect(first('.counter-value').text).to eq('R$ 746.872,44')
      expect(overflowing).to eq(0)
    end
  end
end
