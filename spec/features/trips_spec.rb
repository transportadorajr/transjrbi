require 'rails_helper'

describe 'Trips', flipper: { trips_dashboard: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Viagens', slug: 'trips', writable: false) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  def create_trip(code:, plate:, started_at:, distance_km:, documents:, tenant: self.tenant, **document_attributes)
    create(:atua_manifest, tenant:, code:, number: code.to_s, plate:, trip_started_at: started_at)
    documents.each do |number, freight_cents, driver_code, driver_name|
      create(:atua_transport_document, tenant:, number:, freight_cents:, plate:, driver_code:, driver_name:, issued_at: started_at,
                                       **document_attributes)
      create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: number, calculated_distance_km: distance_km)
    end
  end

  def counter_cards
    all('.counter-card').map { |card| card.text.squish }
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit trips_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the detail of a row to the login screen' do
      visit detail_trips_path(key: 'total')

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no trips in the period' do
      scenario 'shows the empty state with zeroed indicators' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(counter_cards).to eq(['Viagens 0', 'Frete bruto R$ 0,00', 'Média bruta por viagem -', 'Frete bruto por km -', 'KM rodado 0 km',
                                     'Frete líquido R$ 0,00', 'Média líquida por viagem -', 'Frete líquido por km -',
                                     'Tempo médio de conclusão -', 'Em andamento (fora da média) 0'])
      end
    end

    context 'when there are trips of the tenant and of another tenant' do
      before do
        create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 400,
                    documents: [['74001', 300_000, 10, 'JOSE SILVA'], ['74002', 100_000, 20, 'MARIA SOUZA']])
        create_trip(code: 41_002, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 20, 8), distance_km: 0,
                    documents: [['74003', 200_000, 20, 'MARIA SOUZA']])
        create_trip(code: 41_003, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 21, 8), distance_km: 250,
                    documents: [['74004', 500_000, 10, 'JOSE SILVA']])
        create(:freight_expense, tenant:, transport_document: Atua::TransportDocument.find_by!(number: '74004'), amount_cents: 100_000)
        create_trip(tenant: other_tenant, code: 41_004, plate: 'CCC3C33', started_at: Time.zone.local(2026, 10, 5, 8), distance_km: 100,
                    documents: [['74005', 800_000, 30, 'PEDRO OUTRO']])
      end

      scenario 'opens the trips of the current week from the intelligence menu' do
        travel_to(Date.new(2026, 10, 19)) do
          visit root_path
          within('.sidebar-desktop') do
            click_on 'Inteligência'
            click_on 'Viagens'
          end

          expect(page).to have_current_path(trips_path)
          expect(page).to have_css('h1', exact_text: 'Viagens')
          expect(page).to have_text('Viagens iniciadas de 18/10/2026 a 24/10/2026')
          expect(page).to have_link('Motorista', class: 'btn-primary')
        end
      end

      scenario 'lists the trips of the tenant by driver' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(4)
        expect(counter_cards).to eq(['Viagens 3', 'Frete bruto R$ 11.000,00', 'Média bruta por viagem R$ 3.666,67', 'Frete bruto por km R$ 13,85',
                                     'KM rodado 650 km', 'Frete líquido R$ 10.000,00', 'Média líquida por viagem R$ 3.333,33',
                                     'Frete líquido por km R$ 12,31', 'Tempo médio de conclusão -',
                                     'Em andamento (fora da média) 3'])
        expect(find_by_id('trip_durations')).to have_text(
          'Nenhuma viagem do período foi encerrada ainda. O tempo médio aparece quando a primeira for encerrada.',
        )
        expect(all('.counter-card .icon-success').size).to eq(3)
        expect(page).to have_no_css('.trips-table .text-danger')
        expect(page).to have_css('.chart-card', count: 6)
        expect(html_table_to_rows(table: find('.trips-table'))).to eq(
          [
            ['Motorista', 'Frete bruto', 'Bruto/km', 'Líquido/km', 'Tempo médio', 'Ações'],
            ['JOSE SILVA', 'R$ 9.000,00', 'R$ 13,85', 'R$ 12,31', '-', ''],
            ['MARIA SOUZA', 'R$ 2.000,00', '-', '-', '-', ''],
            ['Total', 'R$ 11.000,00', 'R$ 13,85', 'R$ 12,31', '-', ''],
          ],
        )
        expect(page).to have_no_text('PEDRO OUTRO')
      end

      scenario 'shows the gross, net and km the per km is calculated on and the trips left out of it' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(4)
        expect(find_by_id('per_km_base').text.squish).to eq(
          'O R$/km considera R$ 9.000,00 de frete bruto e R$ 8.000,00 de frete líquido em 650 km. ' \
          'Fica de fora 1 MDF-e sem km ou com km inválido (R$ 2.000,00 bruto e R$ 2.000,00 líquido).',
        )
      end

      context 'with access to the manifests' do
        let!(:manifests_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
        let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

        scenario 'warns about the manifest without km linking to it for the correction' do
          visit trips_path(october)

          within('#unmeasured_trips') do
            expect(page).to have_text('1 MDF-e sem km ou com km inválido')
            expect(page).to have_text('acima de 5.000 km')
            expect(all('li').map { |item| item.text.squish }).to eq(['41002 AAA1A11 · 20/10/2026 · 0 km'])
            click_on '41002'
          end

          expect(page).to have_current_path(manifest_path(Atua::Manifest.find_by!(code: 41_002)))
        end

        scenario 'sorts the vehicles from the worst net per km' do
          visit trips_path(october.merge(dimension: 'vehicle'))
          within('.trips-table thead') { click_on 'Líquido/km' }
          within('.trips-table thead') { click_on 'Líquido/km' }

          expect(page).to have_current_path(/direction=asc/)
          expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(['AAA1A11 Pior', 'BBB2B22 Melhor', 'Total'])
        end
      end

      scenario 'offers no grouping by manifest and goes back to the default listing when it is asked for' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(4)
        expect(first('.dashboard-segmented', text: 'Motorista').all('a').map(&:text)).to eq(%w[Motorista Veículo])

        visit trips_path(october.merge(dimension: 'manifest'))

        expect(page).to have_current_path(trips_path)
        expect(page).to have_css('.alert')
        expect(page).to have_link('Motorista', class: 'btn-primary')
        expect(page).to have_no_link('MDF-e')
      end

      scenario 'groups the trips by vehicle keeping the period' do
        visit trips_path(october)
        click_on 'Veículo'

        expect(Atua::Manifest.count).to eq(4)
        expect(page).to have_current_path(/dimension=vehicle/)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1)).to eq(
          [
            ['BBB2B22 Melhor', 'R$ 5.000,00', 'R$ 20,00', 'R$ 16,00', '-', ''],
            ['AAA1A11 Pior', 'R$ 6.000,00', 'R$ 10,00', 'R$ 10,00', '-', ''],
            ['Total', 'R$ 11.000,00', 'R$ 13,85', 'R$ 12,31', '-', ''],
          ],
        )
      end

      scenario 'sorts the vehicles by the gross per km' do
        visit trips_path(october.merge(dimension: 'vehicle'))
        within('.trips-table thead') { click_on 'Bruto/km' }

        expect(Atua::Manifest.count).to eq(4)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(['BBB2B22 Melhor', 'AAA1A11 Pior', 'Total'])
      end

      scenario 'filters the trips by plate' do
        visit trips_path(october.merge(dimension: 'vehicle', plate: 'bbb2b22'))

        expect(Atua::Manifest.count).to eq(4)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(%w[BBB2B22 Total])
      end

      context 'when the trips carry different products' do
        let!(:flour) { create(:product_group, tenant:, name: 'FARINHA') }
        let!(:wheat_flour) { create(:product_subgroup, tenant:, parent: flour, name: 'FARINHA DE TRIGO') }

        before do
          create_trip(code: 41_010, plate: 'DDD4D44', started_at: Time.zone.local(2026, 10, 23, 8), distance_km: 300,
                      documents: [['74010', 600_000, 40, 'ANA FARIAS']], product_group_id: wheat_flour.id)
        end

        scenario 'compares only the trips of the chosen product combined with the other filters' do
          visit trips_path(october.merge(dimension: 'vehicle'))

          expect(all('#product_group_id_select [role="option"]', visible: :all).map { |option| option.text(:all) }).to eq(['FARINHA'])

          visit trips_path(october.merge(dimension: 'vehicle', product_group_id: flour.id))

          expect(Atua::Manifest.count).to eq(5)
          expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(%w[DDD4D44 Total])
          expect(page).to have_no_css('#unmeasured_trips')
          expect(page).to have_no_css('#per_km_base')

          visit trips_path(october.merge(dimension: 'vehicle', product_group_id: flour.id, plate: 'AAA1A11'))

          expect(page).to have_text('Nenhum registro encontrado')
        end

        context 'when other trips carry the same product and another product of the same group' do
          let!(:corn_flour) { create(:product_subgroup, tenant:, parent: flour, name: 'FARINHA DE MILHO') }
          let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
          let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA') }

          def product_options
            all('#product_id_select [role="option"]', visible: :all).map { |option| option.text(:all) }
          end

          before do
            create_trip(code: 41_012, plate: 'FFF6F66', started_at: Time.zone.local(2026, 10, 25, 8), distance_km: 100,
                        documents: [['74013', 300_000, 60, 'RITA LIMA']], product_group_id: wheat_flour.id)
            create_trip(code: 41_013, plate: 'GGG7G77', started_at: Time.zone.local(2026, 10, 26, 8), distance_km: 100,
                        documents: [['74014', 500_000, 70, 'JOAO MELO']], product_group_id: corn_flour.id)
          end

          scenario 'offers every product without a product group and only the products of the selected group' do
            visit trips_path(october.merge(dimension: 'vehicle'))

            expect(product_options).to eq(['BOBINA (SIDERÚRGICO)', 'FARINHA DE MILHO (FARINHA)', 'FARINHA DE TRIGO (FARINHA)'])

            visit trips_path(october.merge(dimension: 'vehicle', product_group_id: flour.id, product_id: wheat_flour.id))

            expect(product_options).to eq(['FARINHA DE MILHO (FARINHA)', 'FARINHA DE TRIGO (FARINHA)'])
            expect(page).to have_field('product_id', type: :hidden, with: wheat_flour.id.to_s)
            expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first))
              .to eq(['FFF6F66 Melhor', 'DDD4D44 Pior', 'Total'])
          end

          scenario 'drops a product that is not of the selected product group from the product options' do
            visit product_options_trips_path(product_group_id: steel.id, product_id: wheat_flour.id)

            expect(product_options).to eq(['BOBINA (SIDERÚRGICO)'])
            expect(page).to have_no_field('product_id', type: :hidden, with: wheat_flour.id.to_s)
          end

          scenario 'reloads the products when another product group is chosen', :js do
            visit trips_path(october.merge(dimension: 'vehicle', product_id: coil.id))
            find(:link, href: '#filtersModal').click

            expect(page).to have_css('#product_id_select .select2-single-value', text: 'BOBINA (SIDERÚRGICO)', visible: :all)

            within('#product_group_id_select') do
              find('.select2-trigger').click
              find('.select2-option', text: 'FARINHA').click
            end

            expect(page).to have_no_css('#product_id_select .select2-single-value', visible: :all)

            within('#product_id_select') do
              find('.select2-trigger').click
              expect(all('.select2-option').map(&:text)).to eq(['FARINHA DE MILHO (FARINHA)', 'FARINHA DE TRIGO (FARINHA)'])
              find('.select2-option', text: 'FARINHA DE TRIGO').click
            end

            click_on 'Aplicar Filtros'

            expect(page).to have_current_path(/product_group_id=#{flour.id}&product_id=#{wheat_flour.id}/)
            expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first))
              .to eq(['FFF6F66 Melhor', 'DDD4D44 Pior', 'Total'])
          end

          scenario 'compares the best and the worst trips of the chosen product by gross freight per km' do
            visit trips_path(october.merge(dimension: 'vehicle', product_id: wheat_flour.id, sort: 'gross_per_km', direction: 'desc'))

            expect(Atua::Manifest.count).to eq(7)
            expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first))
              .to eq(['FFF6F66 Melhor', 'DDD4D44 Pior', 'Total'])
            expect(page).to have_field('product_id', type: :hidden, with: wheat_flour.id.to_s)

            visit trips_path(october.merge(dimension: 'vehicle', product_id: wheat_flour.id, sort: 'gross_per_km', direction: 'asc'))

            expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first))
              .to eq(['DDD4D44 Pior', 'FFF6F66 Melhor', 'Total'])
          end

          scenario 'lists no trip for a product group passed as the product' do
            visit trips_path(october.merge(dimension: 'vehicle', product_id: flour.id))

            expect(page).to have_text('Nenhum registro encontrado')
          end
        end
      end

      context 'when a trip carries a CE' do
        before do
          create_trip(code: 41_011, plate: 'EEE5E55', started_at: Time.zone.local(2026, 10, 24, 8), distance_km: 200,
                      documents: [['74011', 300_000, 50, 'LUIZ CE']], document_kind: 'ce')
          create(:atua_transport_document, tenant:, number: '74012', freight_cents: 200_000, plate: 'EEE5E55', driver_code: 50,
                                           driver_name: 'LUIZ CE', issued_at: Time.zone.local(2026, 10, 24, 8))
          create(:atua_manifest_document, tenant:, manifest_code: 41_011, transport_document_number: '74012', calculated_distance_km: 200)
        end

        scenario 'leaves the CE out of the freight of the vehicle' do
          visit trips_path(october.merge(dimension: 'vehicle', plate: 'EEE5E55'))

          expect(html_table_to_rows(table: find('.trips-table')).drop(1)).to eq(
            [
              ['EEE5E55', 'R$ 2.000,00', 'R$ 10,00', 'R$ 10,00', '-', ''],
              ['Total', 'R$ 2.000,00', 'R$ 10,00', 'R$ 10,00', '-', ''],
            ],
          )
        end
      end
    end

    context 'when the trips were closed' do
      before do
        create_trip(code: 41_021, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 1, 8), distance_km: 400,
                    documents: [['74021', 1_000_000, 10, 'JOSE SILVA']])
        create_trip(code: 41_022, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 300,
                    documents: [['74022', 360_000, 20, 'MARIA SOUZA']])
        create_trip(code: 41_023, plate: 'CCC3C33', started_at: Time.zone.local(2026, 10, 20, 8), distance_km: 300,
                    documents: [['74023', 200_000, 30, 'PEDRO SANTOS']])
        Atua::Manifest.find_by!(code: 41_021).update!(closed_at: Time.zone.local(2026, 10, 3, 10))
        Atua::Manifest.find_by!(code: 41_022).update!(closed_at: Time.zone.local(2026, 10, 3, 8))
      end

      scenario 'shows the average duration of each vehicle from tablets up and sorts from the fastest' do
        visit trips_path(october.merge(dimension: 'vehicle'))

        expect(page).to have_css('.trips-table th.d-md-table-cell', text: 'Tempo médio')

        within('.trips-table thead') { click_on 'Tempo médio' }

        expect(Atua::Manifest.count).to eq(3)
        expect(html_table_to_rows(table: find('.trips-table')).map { |row| [row.first.split.first, row[-2]] }).to eq(
          [
            ['Veículo', 'Tempo médio'],
            ['BBB2B22', '1 dia'],
            ['AAA1A11', '2 dias e 2 horas'],
            ['CCC3C33', '-'],
            ['Total', '1 dia e 13 horas'],
          ],
        )
      end

      scenario 'opens the detail of a vehicle on the page when the link is reached without turbo' do
        visit detail_trips_path(october.merge(dimension: 'vehicle', key: 'AAA1A11'))

        expect(page).to have_current_path(trips_path(october.merge(dimension: 'vehicle', detail: 'AAA1A11')))
        expect(page).to have_css('#remote-container #trip_detail_modal .modal-title', text: 'AAA1A11')
        expect(dl_to_hash('#trip_detail_modal')).to include('Viagens' => '1', 'Tempo médio' => '2 dias e 2 horas')
      end

      scenario 'goes back to the listing with an alert when the row is no longer available' do
        visit detail_trips_path(october.merge(dimension: 'vehicle', key: 'ZZZ9Z99'))

        expect(page).to have_current_path(trips_path(october.merge(dimension: 'vehicle')))
        expect(page).to have_text('Esta linha não está mais disponível. Confira os dados atualizados.')
        expect(page).to have_no_css('#trip_detail_modal')
      end

      context 'when opening the detail of a row', :js do
        def row_detail(label)
          within('.trips-table tr', text: label) { find(:link, title: 'Visualizar').click }
          expect(page).to have_css('#trip_detail_modal.show .modal-title', text: label)

          dl_to_hash('#trip_detail_modal')
        end

        scenario 'shows every figure of the vehicle in a modal injected in the remote container' do
          visit trips_path(october.merge(dimension: 'vehicle'))

          expect(page).to have_css('.trips-table')
          expect(page).to have_no_css('#trip_detail_modal', visible: :all)
          expect(row_detail('AAA1A11')).to eq(
            'Viagens' => '1', 'KM rodado' => '400 km', 'Tempo médio' => '2 dias e 2 horas', 'Frete bruto' => 'R$ 10.000,00',
            'Despesas' => 'R$ 0,00', 'Frete líquido' => 'R$ 10.000,00', 'Média bruta por viagem' => 'R$ 10.000,00',
            'Média líquida por viagem' => 'R$ 10.000,00', 'Bruto/km' => 'R$ 25,00', 'Líquido/km' => 'R$ 25,00'
          )
          expect(page).to have_css('#remote-container #trip_detail_modal')
          expect(page).to have_current_path(trips_path(october.merge(dimension: 'vehicle')))
        end

        scenario 'shows the figures of every trip in the total row' do
          visit trips_path(october.merge(dimension: 'vehicle'))

          expect(row_detail('Total')).to include('Viagens' => '3', 'Frete bruto' => 'R$ 15.600,00', 'Tempo médio' => '1 dia e 13 horas')
        end
      end

      scenario 'shows the average duration and the trips in progress below the indicators without the net freight per hour' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(3)
        expect(all('#trip_durations .counter-card').map { |card| card.text.squish }).to eq(
          ['Tempo médio de conclusão 1 dia e 13 horas', 'Em andamento (fora da média) 1'],
        )
        expect(page).to have_no_text('Nenhuma viagem do período foi encerrada ainda')
        expect(page).to have_no_text('Frete líquido por hora')
      end
    end

    context 'when the trips dashboard is turned off for the tenant' do
      let!(:freight_billing_resource) { create(:resource, name: 'Faturamento', slug: 'freight_billing', writable: false) }

      before do
        Flipper.disable(:trips_dashboard)
        Flipper.enable_actor(:trips_dashboard, other_tenant)
      end

      scenario 'hides the trips from the intelligence menu' do
        visit root_path

        within('.sidebar-desktop') do
          click_on 'Inteligência'

          expect(page).to have_link('Faturamento')
          expect(page).to have_no_link('Viagens')
        end
      end

      scenario 'answers not found for the trips screen' do
        visit trips_path(october)

        expect(page.status_code).to eq(404)
        expect(page).to have_no_css('h1', exact_text: 'Viagens')
      end
    end

    context 'when the end date precedes the start date' do
      scenario 'goes back to the default period with the error' do
        visit trips_path(start_date: '2026-10-31', end_date: '2026-10-01')

        expect(page).to have_current_path(trips_path)
        expect(page).to have_text('Viagens até não pode ser anterior à data inicial')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'without access to the trips' do
      scenario 'is sent back with an access denied message' do
        visit trips_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the trips' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'opens the trips' do
        visit trips_path(october)

        expect(page).to have_css('h1', exact_text: 'Viagens')
        expect(page).to have_text('Nenhum registro encontrado')
      end
    end
  end

  context 'when switching the evolution charts', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 500,
                  documents: [['74001', 1_000_000, 10, 'JOSE SILVA']])
      login_as(owner, scope: :user)
    end

    def visible_chart_titles
      all('.chart-card-title').map(&:text)
    end

    scenario 'shows the monthly evolution first and reveals the weekly one beside the rankings' do
      visit trips_path(october)

      expect(page).to have_button('Mensal', class: 'btn-primary')
      expect(visible_chart_titles).to eq(['Faturamento por Motorista', 'Evolução Mensal do Faturamento', 'R$/km por Motorista',
                                          'Evolução Mensal do R$/km'])

      click_on 'Semanal'

      expect(page).to have_button('Semanal', class: 'btn-primary')
      expect(page).to have_button('Mensal', class: 'btn-outline-secondary')
      expect(visible_chart_titles).to eq(['Faturamento por Motorista', 'Evolução Semanal do Faturamento', 'R$/km por Motorista',
                                          'Evolução Semanal do R$/km'])
      expect(page).to have_current_path(trips_path(october))
      expect(page.evaluate_script(
               "[...document.querySelectorAll('.chart-card canvas')].filter((canvas) => canvas.checkVisibility())" \
               '.every((canvas) => canvas.getBoundingClientRect().width > 0)',
             )).to be(true)
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 500,
                  documents: [['74001', 1_000_000, 10, 'JOSE SILVA']])
      login_as(owner, scope: :user)
    end

    scenario 'draws the monthly charts and keeps only the essential columns without scrolling sideways' do
      use_mobile_screen(width: 360)
      visit trips_path(october)

      expect(page).to have_css('.chart-card canvas', count: 4)
      expect(page).to have_css('.chart-card canvas', count: 6, visible: :all)
      expect(page).to have_css('th', text: /\AMotorista\z/i)
      expect(page).to have_css('th', text: /\AFrete bruto\z/i)
      expect(page).to have_css('th', text: %r{\ALíquido/km\z}i)
      expect(page).to have_no_css('th', text: %r{\ABruto/km\z}i)
      expect(page).to have_no_css('th', text: /\ATempo médio\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      expect(page.evaluate_script('Object.values(Chartkick.charts)[0].getChartObject().data.labels')).to eq(['JOSE SILVA (1)'])
      expect(page.evaluate_script(
        'Object.values(Chartkick.charts).map((chart) => chart.getChartObject().data.datasets.map((dataset) => dataset.backgroundColor))',
      ).uniq).to eq([['#2563eb', '#dc3545']])
    end

    scenario 'keeps the net per km of each vehicle on the phone without scrolling sideways' do
      use_mobile_screen(width: 360)
      visit trips_path(october.merge(dimension: 'vehicle'))

      expect(page).to have_css('th', text: %r{\ALíquido/km\z}i)
      expect(page).to have_css('td', text: 'AAA1A11')
      expect(page).to have_no_css('th', text: /\ADespesas\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
