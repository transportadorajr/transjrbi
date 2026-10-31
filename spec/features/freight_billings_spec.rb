require 'rails_helper'

describe 'Freight billing' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }
  let(:october_by_truck) { october.merge(dimension: 'vehicle') }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit freight_billing_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the detail of a row to the login screen' do
      visit detail_freight_billing_path(key: 'total')

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when the transport documents are readable too' do
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

      scenario 'shows the intelligence menu above the tax menu' do
        visit freight_billing_path

        within('.sidebar-desktop') do
          expect(page).to have_text(/Inteligência.*Fiscal/m)
        end
      end
    end

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

    context 'when sorting the table' do
      before do
        create(:atua_transport_document, tenant:, document_kind: Dashboard::Freight::COMPLEMENT_KIND, posted_on: Date.new(2026, 10, 2),
                                         issued_at: Time.zone.local(2026, 10, 2), plate: 'BBB2B22', freight_cents: 300_000)
        expensive = create(:atua_transport_document, tenant:, document_kind: Dashboard::Freight::COMPLEMENT_KIND, posted_on: Date.new(2026, 10, 3),
                                                     issued_at: Time.zone.local(2026, 10, 3), plate: 'AAA1A11', freight_cents: 500_000)
        create(:freight_expense, tenant:, transport_document: expensive, amount_cents: 450_000)
      end

      scenario 'sorts by the label, the gross and the net keeping the filters' do
        visit freight_billing_path(october_by_truck)
        rows = -> { html_table_to_rows(table: find('.freight-billing-table')).drop(1).map(&:first) }

        expect(Atua::TransportDocument.count).to eq(2)
        expect(rows.call.first(2)).to eq(%w[AAA1A11 BBB2B22])

        within('.freight-billing-table thead') { click_on 'Frete líquido' }
        expect(rows.call.first(2)).to eq(%w[BBB2B22 AAA1A11])
        expect(page).to have_current_path(/start_date=2026-10-01/)

        within('.freight-billing-table thead') { click_on 'Cavalo' }
        expect(rows.call.first(2)).to eq(%w[AAA1A11 BBB2B22])
      end
    end

    context 'when there are no trips in the period' do
      scenario 'shows the empty state with zeroed indicators' do
        visit freight_billing_path(october)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 0,00', 'Frete líquido R$ 0,00',
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

      def monthly_bar_labels
        expect(page).to have_css('.chart-card canvas', count: 2)

        page.document.synchronize do
          page.evaluate_script(
            '(Object.values(Chartkick.charts)[1].getChartObject().$datalabels?._labels || [])' \
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
        create(:atua_transport_document, tenant:, number: '74001', branch_code: 2, freight_cents: 1_000_000, weight_freight_cents: 900_000,
                                         toll_cents: 25_000, icms_cents: 75_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02', driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7100, origin_city: 'IPATINGA',
                                         origin_state: 'MG')
      end
      let!(:steel_toll_voucher) { create(:atua_toll_voucher, tenant:, transport_document_number: '74001', branch_code: 2, toll_cents: 25_000) }
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
          expect(page).to have_link('Grupo de clientes', class: 'btn-primary')
        end
      end

      scenario 'lists the groupings starting from the customer group' do
        visit freight_billing_path(october)

        expect(all('.dashboard-segmented[aria-label="Agrupar por"] .btn').map(&:text)).to eq(['Grupo de clientes', 'Cavalo', 'Motorista', 'Origem', 'Macro região'])
      end

      scenario 'shows the gross and net freight per truck discounting the toll vouchers of the transport documents' do
        visit freight_billing_path(october_by_truck)

        expect(Atua::TransportDocument.count).to eq(5)
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 20.000,00', 'Frete líquido R$ 19.100,00', 'Viagens 2', 'Frete bruto por km R$ 26,39', 'Frete líquido por km R$ 25,14',
           'KM rodado 720 km'],
        )
        expect(page).to have_text('Frete por Cavalo')
        expect(page).to have_text('Evolução Mensal')
        expect(page).to have_text('Frete bruto e líquido por mês de emissão do CT-e, de Mai/2026 a Out/2026')
        expect(html_table_to_rows).to eq(
          [
            ['Cavalo', 'Frete bruto', 'Frete líquido', 'Pedágio', 'Participação', 'Ações'],
            ['RVR2C34', 'R$ 15.000,00', 'R$ 14.100,00', 'R$ 250,00', '75,0%', ''],
            ['RVR8J90', 'R$ 5.000,00', 'R$ 5.000,00', 'R$ 0,00', '25,0%', ''],
            ['Total', 'R$ 20.000,00', 'R$ 19.100,00', 'R$ 250,00', '100,0%', ''],
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
          visit freight_billing_path(october_by_truck)

          expect(Atua::TransportDocument.count).to eq(6)
          expect(ranking_bar_labels).to contain_exactly(
            ['R$ 15.000,00', '#ffffff'], ['R$ 5.000,00', '#ffffff'], ['R$ 300,00', '#2563eb'],
            ['R$ 14.100,00', '#ffffff'], ['R$ 5.000,00', '#ffffff'], ['R$ 300,00', '#eb6834']
          )
        end

        scenario 'writes the monthly values on horizontal bars in their own colors', :js do
          visit freight_billing_path(october_by_truck)

          expect(Atua::TransportDocument.count).to eq(6)
          expect(monthly_bar_labels).to contain_exactly(['R$ 20.300,00', '#ffffff'], ['R$ 19.400,00', '#ffffff'])
          expect(page.evaluate_script('Object.values(Chartkick.charts)[1].getChartObject().options.indexAxis')).to eq('y')
          expect(page.evaluate_script('Object.values(Chartkick.charts)[1].getChartObject().data.datasets.map((dataset) => dataset.backgroundColor)')).to eq(
            %w[#dc3545 #198754],
          )
        end

        context 'when clicking on a month of the monthly chart', :js do
          def click_month(label)
            expect(page).to have_css('[data-controller="ranking-chart"] canvas', count: 2)

            page.execute_script(<<~JS, label)
              const [label] = arguments;
              const chart = Object.values(Chartkick.charts)[1].getChartObject();
              const rect = chart.canvas.getBoundingClientRect();
              const y = chart.scales.y.getPixelForValue(chart.data.labels.indexOf(label));
              chart.canvas.dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: rect.left + chart.chartArea.left + 10, clientY: rect.top + y }));
            JS
          end

          scenario 'opens the freights issued in that month with the totals of its bars' do
            visit freight_billing_path(october_by_truck)
            click_month('Out/2026')

            expect(page).to have_css('#freight_billing_freights_modal.show .modal-title', text: 'Out/2026')
            within('#freight_billing_freights_modal') do
              expect(page).to have_text('CT-es emitidos em Out/2026')
              rows = html_table_to_rows
              expect(rows[1..-2].size).to eq(Atua::TransportDocument.where(tenant:).count)
              expect(rows.last).to include('R$ 20.300,00', 'R$ 19.400,00')
            end
            expect(page).to have_current_path(freight_billing_path(october_by_truck))
          end

          scenario 'opens nothing from a month without freights' do
            visit freight_billing_path(october_by_truck)
            click_month('Mai/2026')

            expect(page).to have_no_css('#freight_billing_freights_modal')
          end

          scenario 'shows no tooltip on the monthly chart' do
            visit freight_billing_path(october_by_truck)
            expect(page).to have_css('[data-controller="ranking-chart"] canvas', count: 2)

            expect(page.evaluate_script('Object.values(Chartkick.charts)[1].getChartObject().options.plugins.tooltip.enabled')).to be(false)
            expect(monthly_bar_labels).to include(['R$ 20.300,00', '#ffffff'])
          end
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
            visit freight_billing_path(october_by_truck)

            expect(Atua::TransportDocument.count).to eq(18)
            expect(ranking_bar_labels.size).to eq(30)
            expect(ranking_bar_labels).to include(['R$ 14.100,00', '#ffffff'], ['R$ 2.500,00', '#ffffff'])
            expect(ranking_bar_labels.count(['R$ 500,00', '#eb6834'])).to eq(12)
          end
        end
      end

      context 'when a customer group has a trip of the truck left out of the truck ranking' do
        before do
          create(:atua_manifest, tenant:, code: 41_020, plate: 'INT6R00', trip_started_at: Time.zone.local(2026, 10, 12, 7))
          create(:atua_transport_document, tenant:, number: '74020', freight_cents: 600_000, plate: 'INT6R00', driver_code: 40,
                                           driver_name: 'JECI FERREIRA DE SOUZA JUNIOR', taker_code: 7100)
          create(:atua_manifest_document, tenant:, manifest_code: 41_020, transport_document_number: '74020', calculated_distance_km: 50)
        end

        scenario 'plots the same gross and net freight of the customer group as the table', :js do
          visit freight_billing_path(october)

          usiminas_row = html_table_to_rows.find { |row| row.first == 'USIMINAS' }

          expect(Atua::TransportDocument.count).to eq(6)
          expect(usiminas_row[1..2]).to eq(['R$ 21.000,00', 'R$ 20.100,00'])
          expect(ranking_bar_labels.map(&:first)).to include('R$ 21.000,00', 'R$ 20.100,00')
        end
      end

      scenario 'groups the freight by driver keeping the period' do
        visit freight_billing_path(october)
        click_on 'Motorista'

        expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'driver')))
        expect(page).to have_link('Motorista', class: 'btn-primary')
        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2) }).to eq(
          [
            ['Motorista', 'Frete bruto', 'Frete líquido'],
            ['JOSE SILVA', 'R$ 15.000,00', 'R$ 14.100,00'],
            ['MARIA SOUZA', 'R$ 5.000,00', 'R$ 5.000,00'],
            ['Total', 'R$ 20.000,00', 'R$ 19.100,00'],
          ],
        )
      end

      scenario 'splits a shared trip between the customer groups by their share of its freight' do
        visit freight_billing_path(october.merge(dimension: 'customer_group'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 1) }).to eq(
          [
            ['Grupo de clientes', 'Frete bruto'],
            ['USIMINAS', 'R$ 15.000,00'],
            ['Sem grupo', 'R$ 5.000,00'],
            ['Total', 'R$ 20.000,00'],
          ],
        )
      end

      scenario 'groups the freight by origin' do
        visit freight_billing_path(october.merge(dimension: 'origin'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 4) }).to eq(
          [
            ['Origem', 'Frete bruto', 'Participação'],
            ['IPATINGA/MG', 'R$ 15.000,00', '75,0%'],
            ['BELO HORIZONTE/MG', 'R$ 5.000,00', '25,0%'],
            ['Total', 'R$ 20.000,00', '100,0%'],
          ],
        )
      end

      context 'when opening the detail of a row', :js do
        def row_detail(label)
          within('.freight-billing-table tr', text: label) { find(:link, title: 'Visualizar').click }
          expect(page).to have_css('#freight_billing_detail_modal.show .modal-title', text: label)

          dl_to_hash('#freight_billing_detail_modal')
        end

        def close_detail
          page.document.synchronize do
            within('#freight_billing_detail_modal') { find('.btn-close').click }
            raise Capybara::ExpectationNotMet if page.has_css?('.modal.show', wait: 0.5)
          end
        end

        scenario 'shows every figure of the truck in a modal injected in the remote container' do
          visit freight_billing_path(october_by_truck)

          expect(page).to have_css('.freight-billing-table')
          expect(page).to have_no_css('#freight_billing_detail_modal', visible: :all)
          expect(row_detail('RVR2C34')).to eq(
            'Viagens' => '1', 'KM rodado' => '520 km', 'Frete bruto' => 'R$ 15.000,00', 'Despesas de frete' => 'R$ 500,00',
            'Despesas' => 'R$ 150,00', 'Pedágio' => 'R$ 250,00', 'Frete líquido' => 'R$ 14.100,00', 'Bruto/km' => 'R$ 28,85',
            'Líquido/km' => 'R$ 27,12', 'Participação' => '75,0%'
          )
          expect(page).to have_css('#remote-container #freight_billing_detail_modal')
          expect(page).to have_current_path(freight_billing_path(october_by_truck))
        end

        scenario 'keeps a single modal on the page when another row is opened' do
          visit freight_billing_path(october_by_truck)
          row_detail('RVR2C34')
          close_detail

          expect(row_detail('RVR8J90')).to include('KM rodado' => '200 km', 'Frete bruto' => 'R$ 5.000,00')
          expect(page).to have_css('.modal.show', count: 1)
          expect(page).to have_css('#freight_billing_detail_modal', count: 1)
        end

        scenario 'shows the discounts of the whole report in the total row' do
          visit freight_billing_path(october)

          expect(row_detail('Total')).to eq(
            'Viagens' => '2', 'KM rodado' => '720 km', 'Frete bruto' => 'R$ 20.000,00', 'Despesas de frete' => 'R$ 500,00',
            'Despesas' => 'R$ 150,00', 'Pedágio' => 'R$ 250,00', 'Frete líquido' => 'R$ 19.100,00', 'Bruto/km' => 'R$ 26,39',
            'Líquido/km' => 'R$ 25,14', 'Participação' => '100,0%'
          )
        end

        context 'with a toll charged apart from the gross freight' do
          before do
            create(:atua_transport_document, tenant:, number: '74009', freight_cents: 600_000, weight_freight_cents: 600_000, toll_cents: 40_000,
                                             icms_cents: 0, plate: 'RVR8J90', driver_code: 20, driver_name: 'MARIA SOUZA')
            create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74009')
          end

          scenario 'shows the toll of the row without discounting it from the net freight' do
            visit freight_billing_path(october_by_truck)

            detail = row_detail('RVR8J90')

            expect(detail).to include('Pedágio (Não descontado)' => 'R$ 400,00', 'Frete bruto' => 'R$ 11.000,00', 'Frete líquido' => 'R$ 11.000,00')
            expect(detail).not_to have_key('Pedágio')
            expect(html_table_to_rows.find { |row| row.first == 'RVR8J90' }).to include('R$ 400,00')
          end

          scenario 'shows both tolls when the row mixes a discounted toll and one that is not' do
            visit freight_billing_path(october_by_truck)

            expect(row_detail('Total')).to include('Pedágio' => 'R$ 250,00', 'Pedágio (Não descontado)' => 'R$ 400,00')
          end
        end

        scenario 'opens the detail of a driver' do
          visit freight_billing_path(october.merge(dimension: 'driver'))

          expect(row_detail('JOSE SILVA')).to include('Viagens' => '1', 'Frete bruto' => 'R$ 15.000,00')
        end

        scenario 'opens the detail of a customer group with the shared trip split and of the documents without a group' do
          visit freight_billing_path(october.merge(dimension: 'customer_group'))

          expect(row_detail('USIMINAS')).to include('Viagens' => '1,7', 'KM rodado' => '547 km', 'Frete bruto' => 'R$ 15.000,00')
          close_detail
          expect(row_detail('Sem grupo')).to include('Viagens' => '0,3', 'KM rodado' => '173 km', 'Frete bruto' => 'R$ 5.000,00')
        end

        scenario 'opens the detail of an origin' do
          visit freight_billing_path(october.merge(dimension: 'origin'))

          expect(row_detail('BELO HORIZONTE/MG')).to include('Frete bruto' => 'R$ 5.000,00', 'Participação' => '25,0%')
        end

        scenario 'opens the detail of the origins out of every macro region' do
          visit freight_billing_path(october.merge(dimension: 'macro_region'))

          expect(row_detail('Outras Regiões')).to include('Frete bruto' => 'R$ 20.000,00', 'Participação' => '100,0%')
        end

        scenario 'respects the filters of the screen' do
          visit freight_billing_path(october_by_truck.merge(customer_group_id: usiminas.id))

          expect(row_detail('RVR2C34')).to include('Frete bruto' => 'R$ 10.000,00')
        end

        scenario 'does not open the modal again when coming back to the screen' do
          visit freight_billing_path(october_by_truck)
          row_detail('RVR2C34')
          close_detail
          click_on 'Motorista'
          expect(page).to have_link('Motorista', class: 'btn-primary')
          page.go_back

          expect(page).to have_link('Cavalo', class: 'btn-primary')
          expect(page).to have_no_css('#freight_billing_detail_modal', visible: :all)
        end

        scenario 'keeps the view button reachable and the page from scrolling sideways on a phone even with large values' do
          create(:atua_manifest, tenant:, code: 41_020, plate: 'RVR7K77', trip_started_at: Time.zone.local(2026, 10, 12, 7))
          create(:atua_transport_document, tenant:, number: '74020', freight_cents: 123_456_789, plate: 'RVR7K77')
          create(:atua_manifest_document, tenant:, manifest_code: 41_020, transport_document_number: '74020', calculated_distance_km: 50)

          use_mobile_screen(width: 360)
          visit freight_billing_path(october_by_truck)

          eye_visible = "document.querySelector('.freight-billing-table tbody a[title=Visualizar]').getBoundingClientRect().right <= " \
                        "document.querySelector('.table-responsive').getBoundingClientRect().right"
          expect(page.evaluate_script(eye_visible)).to be(true)
          expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
          expect(row_detail('RVR7K77')).to include('Frete bruto' => 'R$ 1.234.567,89')
          expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
        end
      end

      context 'when opening the freights of a row', :js do
        def open_freights(label)
          within('.freight-billing-table tbody') { click_link label }
          expect(page).to have_css('#freight_billing_freights_modal.show .modal-title', text: label)
        end

        def modal_numbers
          within('#freight_billing_freights_modal') { html_table_to_rows[1..-2].map { |row| row.first.split.first } }
        end

        def close_freights
          page.document.synchronize do
            within('#freight_billing_freights_modal') { find('.btn-close').click }
            raise Capybara::ExpectationNotMet if page.has_css?('.modal.show', wait: 0.5)
          end
        end

        def modal_total
          within('#freight_billing_freights_modal') { html_table_to_rows.last }
        end

        scenario 'lists the freights of the truck in a modal injected in the remote container' do
          visit freight_billing_path(october_by_truck)

          expect(page).to have_css('.freight-billing-table')
          expect(page).to have_no_css('#freight_billing_freights_modal', visible: :all)
          open_freights('RVR2C34')

          expect(page).to have_css('#remote-container #freight_billing_freights_modal')
          expect(modal_numbers).to contain_exactly('74001', '74002')
          expect(modal_total).to eq(['Total', '', '', '', '', 'R$ 15.000,00', 'R$ 14.100,00'])
          expect(page).to have_current_path(freight_billing_path(october_by_truck))
        end

        scenario 'lists the freights of the driver, the complement included' do
          visit freight_billing_path(october.merge(dimension: 'driver'))
          open_freights('MARIA SOUZA')

          expect(modal_numbers).to contain_exactly('74003', '3547')
          expect(modal_total).to eq(['Total', '', '', '', '', 'R$ 5.000,00', 'R$ 5.000,00'])
        end

        scenario 'keeps a single modal on the page when another row is opened' do
          visit freight_billing_path(october_by_truck)
          open_freights('RVR2C34')
          close_freights
          open_freights('RVR8J90')

          expect(page).to have_css('#freight_billing_freights_modal', count: 1)
          expect(modal_numbers).to contain_exactly('74003', '3547')
        end

        context 'when the transport documents are readable' do
          let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

          scenario 'opens the transport document from the modal' do
            visit freight_billing_path(october_by_truck)
            open_freights('RVR2C34')
            within('#freight_billing_freights_modal') { click_link '74001' }

            expect(page).to have_current_path(transport_document_path(steel))
            expect(page).to have_no_css('.modal-backdrop')
          end
        end

        scenario 'fits a phone screen' do
          use_mobile_screen
          visit freight_billing_path(october_by_truck)
          open_freights('RVR2C34')

          expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
        end
      end

      context 'when clicking on the ranking chart', :js do
        def click_ranking(label, on:)
          expect(page).to have_css('.chart-card canvas', count: 2)
          expect(page).to have_css('[data-controller="ranking-chart"] canvas')

          page.execute_script(<<~JS, label, on.to_s)
            const [label, on] = arguments;
            const chart = Object.values(Chartkick.charts)[0].getChartObject();
            const rect = chart.canvas.getBoundingClientRect();
            const y = chart.scales.y.getPixelForValue(chart.data.labels.indexOf(label));
            const x = on === 'name' ? chart.chartArea.left - 10 : chart.chartArea.left + 10;
            chart.canvas.dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: rect.left + x, clientY: rect.top + y }));
          JS
          expect(page).to have_css('#freight_billing_freights_modal.show .modal-title', text: label)
          within('#freight_billing_freights_modal') { html_table_to_rows[1..-2].map { |row| row.first.split.first } }
        end

        scenario 'opens the freights of the truck from its bar' do
          visit freight_billing_path(october_by_truck)

          expect(click_ranking('RVR2C34', on: :bar)).to contain_exactly('74001', '74002')
          expect(page).to have_current_path(freight_billing_path(october_by_truck))
        end

        scenario 'opens the freights of the truck from its name on the chart' do
          visit freight_billing_path(october_by_truck)

          expect(click_ranking('RVR8J90', on: :name)).to contain_exactly('74003', '3547')
        end

        scenario 'opens the freights of the driver from the chart' do
          visit freight_billing_path(october.merge(dimension: 'driver'))

          expect(click_ranking('JOSE SILVA', on: :bar)).to contain_exactly('74001', '74002')
          expect(page).to have_css('#freight_billing_freights_modal', count: 1)
        end
      end

      scenario 'redirects a month out of the monthly chart back to the report' do
        visit month_freight_billing_path(october_by_truck.merge(month: '2020-01'))

        expect(page).to have_current_path(freight_billing_path(october_by_truck))
        expect(page).to have_text('Este mês não está mais disponível. Confira os dados atualizados.')
      end

      scenario 'makes only the ranking of the trucks and the drivers clickable' do
        visit freight_billing_path(october_by_truck)
        expect(page).to have_css('[data-controller="ranking-chart"]', count: 2)

        visit freight_billing_path(october)
        expect(page).to have_css('.chart-card')
        expect(page).to have_css('[data-controller="ranking-chart"]', count: 1)
      end

      scenario 'links only the trucks and the drivers to their freights' do
        visit freight_billing_path(october_by_truck)
        expect(page).to have_css('.freight-billing-table tbody .freight-billing-label a', text: 'RVR2C34')
        expect(page).to have_no_css('.freight-billing-table tfoot .freight-billing-label a')

        visit freight_billing_path(october)
        expect(page).to have_css('.freight-billing-table')
        expect(page).to have_no_css('.freight-billing-table .freight-billing-label a')
      end

      scenario 'goes back to the report with an alert when the freights are asked for a row out of the list' do
        visit freights_freight_billing_path(october)

        expect(page).to have_current_path(freight_billing_path(october))
        expect(page).to have_text('Esta linha não está mais disponível. Confira os dados atualizados.')
      end

      scenario 'goes back to the report with an alert when the row is no longer in it' do
        visit detail_freight_billing_path(october.merge(key: 'OUT1A11'))

        expect(page).to have_current_path(freight_billing_path(october))
        expect(page).to have_text('Esta linha não está mais disponível. Confira os dados atualizados.')
        expect(page).to have_no_text('OUT1A11')
      end

      context 'when the origins belong to macro regions' do
        let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH', state: 'MG', cities: ['Belo Horizonte', 'Betim']) }

        before { MacroRegions::AssignCommand.call(tenant) }

        scenario 'groups the freight by the macro region of the origin with the other origins apart' do
          visit freight_billing_path(october)
          click_on 'Macro região'

          expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'macro_region')))
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 4) }).to eq(
            [
              ['Macro região', 'Frete bruto', 'Participação'],
              ['Outras Regiões', 'R$ 15.000,00', '75,0%'],
              ['GRANDE BH', 'R$ 5.000,00', '25,0%'],
              ['Total', 'R$ 20.000,00', '100,0%'],
            ],
          )
        end

        scenario 'filters by a macro region of origin' do
          visit freight_billing_path(october_by_truck)
          select 'GRANDE BH', from: 'Macro região de origem'
          click_on 'Aplicar Filtros'

          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')
          expect(page).to have_select('Macro região de origem', selected: 'GRANDE BH', visible: :all)
        end

        scenario 'filters by the origins out of every macro region' do
          visit freight_billing_path(october_by_truck)
          select 'Outras Regiões', from: 'Macro região de origem'
          click_on 'Aplicar Filtros'

          expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
          expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 15.000,00')
        end
      end

      scenario 'filters by plate and customer group' do
        visit freight_billing_path(october_by_truck.merge(customer_group_id: usiminas.id))
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

        scenario 'adds the freight of the documents without a trip to the gross and the net freight like the Atua report' do
          visit freight_billing_path(october)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(8)
          expect(all('.counter-card').first(2).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.869,00', 'Frete líquido R$ 19.969,00'],
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
          visit freight_billing_path(october_by_truck)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(5)
          expect(all('.counter-card').first(3).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.000,00', 'Frete líquido R$ 19.100,00', 'Viagens 3'],
          )
          expect(html_table_to_rows.map { |row| row.values_at(0, 1) }).to include(['RHJ5A50', 'R$ 6.073,32'])

          visit freight_billing_path(start_date: '2026-09-01', end_date: '2026-09-30', dimension: 'vehicle')

          expect(all('.counter-card').first(3).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 6.073,32', 'Frete líquido R$ 6.073,32', 'Viagens 0'],
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
          visit freight_billing_path(october_by_truck)

          expect(Atua::TransportDocument.where(tenant:).count).to eq(7)
          expect(all('.counter-card').map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 20.000,00', 'Frete líquido R$ 19.100,00', 'Viagens 2', 'Frete bruto por km R$ 26,39', 'Frete líquido por km R$ 25,14',
             'KM rodado 720 km'],
          )
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2) }).to eq(
            [
              ['Cavalo', 'Frete bruto', 'Frete líquido'],
              ['RVR2C34', 'R$ 15.000,00', 'R$ 14.100,00'],
              ['RVR8J90', 'R$ 5.000,00', 'R$ 5.000,00'],
              ['Total', 'R$ 20.000,00', 'R$ 19.100,00'],
            ],
          )
        end

        scenario 'leaves the documents of the excluded issuers out of the customer groups' do
          visit freight_billing_path(october.merge(dimension: 'customer_group'))

          expect(html_table_to_rows.map { |row| row.values_at(0, 1) }).to eq(
            [
              ['Grupo de clientes', 'Frete bruto'],
              ['USIMINAS', 'R$ 15.000,00'],
              ['Sem grupo', 'R$ 5.000,00'],
              ['Total', 'R$ 20.000,00'],
            ],
          )
        end

        scenario 'counts the documents of an issuer again once it is considered' do
          maycon.destroy!

          visit freight_billing_path(october)

          expect(all('.counter-card').first(2).map { |card| card.text.squish }).to eq(
            ['Frete bruto R$ 40.179,20', 'Frete líquido R$ 39.279,20'],
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
          visit freight_billing_path(october_by_truck)

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
            visit freight_billing_path(october_by_truck)

            expect(TruckGroup.count).to eq(6)
            expect(page).to have_select('Tipo de conjunto', options: ['Todos', 'LS', 'Outros', 'Quarto eixo', 'Rodotrem'])
            expect(page).to have_text('Pela placa do cavalo ou pela quantidade de eixos informada em cada CT-e.')

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
            visit freight_billing_path(october_by_truck.merge(truck_group_id: ls.id))

            expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')

            visit freight_billing_path(october_by_truck.merge(truck_group_id: rodotrem.id))

            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 10.000,00')
          end
        end

        context 'with a group of plates' do
          let!(:utinga) { create(:truck_group, tenant:, name: 'Utinga', axles: [], plates: %w[RVR8J90], fuel_percentage: 28) }

          before { sheet.update!(axles: 9) }

          scenario 'counts each transport document only in the group of its plate' do
            visit freight_billing_path(october_by_truck.merge(truck_group_id: utinga.id))

            expect(TruckGroup.count).to eq(6)
            expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR8J90 Total])
            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')

            visit freight_billing_path(october_by_truck.merge(truck_group_id: rodotrem.id))

            expect(html_table_to_rows.map(&:first)).to eq(%w[Cavalo RVR2C34 Total])
            expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 15.000,00')

            visit freight_billing_path(october.merge(truck_group_id: 'none'))

            expect(page).to have_text('Nenhum registro encontrado')
          end
        end

        scenario 'rejects an unknown truck group' do
          visit freight_billing_path(october.merge(truck_group_id: 'rodotrem'))

          expect(page).to have_current_path(freight_billing_path)
          expect(page).to have_text('Tipo de conjunto não é válido')
        end
      end

      scenario 'filters by another period' do
        visit freight_billing_path(october_by_truck)
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

          expect(page).to have_link('Sem. atual', class: 'btn-primary')
          expect(page).to have_link('Mês', exact: true, class: 'btn-outline-secondary')

          click_on 'Mês'

          expect(page).to have_text('Saídas de 01/10/2026 a 31/10/2026')
          expect(page).to have_field('Saídas a partir de', with: '2026-10-01')
          expect(page).to have_field('Saídas até', with: '2026-10-31')
          expect(page).to have_link('Mês', exact: true, class: 'btn-primary')
          expect(page).to have_link('Sem. atual', class: 'btn-outline-secondary')

          click_on 'Sem. passada'

          expect(page).to have_text('Saídas de 11/10/2026 a 17/10/2026')
          expect(page).to have_link('Sem. passada', class: 'btn-primary')

          click_on 'Mês passado'

          expect(page).to have_text('Saídas de 01/09/2026 a 30/09/2026')
          expect(page).to have_link('Mês passado', class: 'btn-primary')
          expect(page).to have_link('Mês', exact: true, class: 'btn-outline-secondary')

          click_on 'Hoje'

          expect(page).to have_text('Saídas de 19/10/2026 a 19/10/2026')
          expect(page).to have_link('Hoje', class: 'btn-primary')

          click_on 'Sem. atual'

          expect(page).to have_text('Saídas de 18/10/2026 a 24/10/2026')
          expect(page).to have_link('Sem. atual', class: 'btn-primary')
        end
      end

      scenario 'highlights no shortcut on a custom period' do
        visit freight_billing_path(start_date: '2026-10-05', end_date: '2026-10-06')

        expect(page).to have_text('Saídas de 05/10/2026 a 06/10/2026')
        expect(page).to have_no_css('a.btn-primary', text: /\A(Sem. atual|Sem. passada|Mês|Mês passado|Hoje)\z/)
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
          visit freight_billing_path(october_by_truck)

          expect(Atua::Expense.count).to eq(6)
          expect(find('table')).to have_no_text('Combustível')
          expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2) }).to eq(
            [
              ['Cavalo', 'Frete bruto', 'Frete líquido'],
              ['RVR2C34', 'R$ 15.000,00', 'R$ 14.100,00'],
              ['RVR8J90', 'R$ 5.000,00', 'R$ 5.000,00'],
              ['PUR1A81', 'R$ 3.000,00', 'R$ 3.000,00'],
              ['Total', 'R$ 23.000,00', 'R$ 22.100,00'],
            ],
          )
          expect(all('.counter-card')[1].text.squish).to eq('Frete líquido R$ 22.100,00')
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
      expect(page).to have_css('th', text: /\AFrete bruto\z/i)
      expect(page).to have_css('th', text: /\AParticipação\z/i)
      expect(page).to have_css('th', text: /\AAções\z/i)
      expect(page).to have_no_css('th', text: /\AKM rodado\z/i)
      expect(page).to have_no_css('th', text: /\APedágio\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the period shortcuts above the groupings and the groupings above the indicators' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      grouping_bottom = page.evaluate_script("document.querySelector('.dashboard-segmented[aria-label=\"Agrupar por\"]').getBoundingClientRect().bottom")
      first_card_top = page.evaluate_script("document.querySelector('.counter-card').getBoundingClientRect().top")
      grouping_top = page.evaluate_script("document.querySelector('.dashboard-segmented[aria-label=\"Agrupar por\"]').getBoundingClientRect().top")
      shortcut_bottom = page.evaluate_script("[...document.querySelectorAll('a')].find((link) => link.textContent.trim() === 'Hoje').getBoundingClientRect().bottom")

      expect(grouping_bottom).to be <= first_card_top
      expect(shortcut_bottom).to be <= grouping_top
    end

    scenario 'lists what is discounted from the net freight above the indicators' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      discounts = 'Frete líquido é descontado do frete bruto: Comissões, Brasiltec, Seguro, Combustível, Descarga e Pedágio'
      discounts_bottom = page.evaluate_script("document.querySelector('.net-freight-discounts').getBoundingClientRect().bottom")
      first_card_top = page.evaluate_script("document.querySelector('.counter-card').getBoundingClientRect().top")

      expect(page).to have_css('.net-freight-discounts.fst-italic.fw-bold.text-success', text: discounts)
      expect(page).to have_no_css('.counter-card', text: discounts)
      expect(discounts_bottom).to be <= first_card_top
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the indicators two per row and the grouping options in a single swipeable line' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      card_tops = page.evaluate_script("[...document.querySelectorAll('.counter-card')].map((card) => card.getBoundingClientRect().top)")
      option_tops = page.evaluate_script("[...document.querySelectorAll('.dashboard-segmented[aria-label=\"Agrupar por\"] .btn')].map((option) => option.getBoundingClientRect().top)")
      title_top = page.evaluate_script("document.querySelector('.page-title').getBoundingClientRect().top")
      filter_top = page.evaluate_script("document.querySelector('.page-actions').getBoundingClientRect().top")

      expect(card_tops.each_slice(2).map { |pair| pair.uniq.size }).to eq([1, 1, 1])
      expect(card_tops.uniq.size).to eq(3)
      expect(option_tops.uniq.size).to eq(1)
      expect(filter_top).to be <= title_top
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the period shortcuts without opening the modal or scrolling sideways' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      expect(all('.dashboard-filter-label').map(&:text)).to eq(['DATA', 'AGRUPAR POR'])
      expect(page).to have_link('Sem. atual')
      expect(page).to have_link('Sem. passada')
      expect(page).to have_link('Mês', exact: true)
      expect(page).to have_link('Mês passado')
      expect(page).to have_link('Hoje')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'shows the period shortcuts in a single swipeable line like the groupings' do
      use_mobile_screen(width: 360)
      visit freight_billing_path(october)

      shortcut_tops = page.evaluate_script("[...document.querySelectorAll('.dashboard-segmented[aria-label=\"Data\"] .btn')].map((option) => option.getBoundingClientRect().top)")

      expect(shortcut_tops.size).to eq(5)
      expect(shortcut_tops.uniq.size).to eq(1)
    end
  end

  context 'when there are more rows than fit on a page' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      12.times do |index|
        plate = "RVR4D#{index.to_s.rjust(2, '0')}"
        number = (76_000 + index).to_s
        create(:atua_manifest, tenant:, code: 43_000 + index, plate:, trip_started_at: Time.zone.local(2026, 10, 12, 7))
        create(:atua_transport_document, tenant:, number:, freight_cents: 200_000 - (index * 10_000), plate:)
        create(:atua_manifest_document, tenant:, manifest_code: 43_000 + index, transport_document_number: number, calculated_distance_km: 50)
      end
      login_as(admin, scope: :user)
    end

    def listed_plates
      html_table_to_rows.drop(1).map(&:first)
    end

    scenario 'lists ten rows per page and keeps the total of the whole report on every page' do
      visit freight_billing_path(october_by_truck)

      expect(Atua::TransportDocument.count).to eq(12)
      expect(listed_plates).to eq(%w[RVR4D00 RVR4D01 RVR4D02 RVR4D03 RVR4D04 RVR4D05 RVR4D06 RVR4D07 RVR4D08 RVR4D09 Total])
      expect(html_table_to_rows.last).to eq(['Total', 'R$ 17.400,00', 'R$ 17.400,00', 'R$ 0,00', '100,0%', ''])

      within('.table-pagination') { click_on '2' }

      expect(page).to have_current_path(freight_billing_path(october_by_truck.merge(page: 2)))
      expect(listed_plates).to eq(%w[RVR4D10 RVR4D11 Total])
      expect(html_table_to_rows.last).to eq(['Total', 'R$ 17.400,00', 'R$ 17.400,00', 'R$ 0,00', '100,0%', ''])
    end

    scenario 'goes back to the first page when the grouping changes' do
      visit freight_billing_path(october.merge(page: 2))
      click_on 'Motorista'

      expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'driver')))
    end

    scenario 'goes back to the first page when the period changes' do
      visit freight_billing_path(october.merge(page: 2))
      click_on 'Mês passado'

      expect(page).to have_link('Mês passado', class: 'btn-primary')
      expect(page.current_url).not_to include('page=')
    end

    scenario 'opens the detail of a row of the second page', :js do
      visit freight_billing_path(october_by_truck.merge(page: 2))
      within('.freight-billing-table tr', text: 'RVR4D10') { find(:link, title: 'Visualizar').click }

      expect(page).to have_css('#freight_billing_detail_modal.show .modal-title', text: 'RVR4D10')
      expect(dl_to_hash('#freight_billing_detail_modal')).to include('Frete bruto' => 'R$ 1.000,00')
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
