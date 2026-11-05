require 'rails_helper'

describe 'Trips', flipper: { trips_dashboard: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Viagens', slug: 'trips', writable: false) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  def create_trip(code:, plate:, started_at:, distance_km:, documents:, tenant: self.tenant)
    create(:atua_manifest, tenant:, code:, plate:, trip_started_at: started_at)
    documents.each do |number, freight_cents, driver_code, driver_name|
      create(:atua_transport_document, tenant:, number:, freight_cents:, plate:, driver_code:, driver_name:, issued_at: started_at)
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
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no trips in the period' do
      scenario 'shows the empty state with zeroed indicators' do
        visit trips_path(october)

        expect(Atua::Manifest.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(counter_cards).to eq(['Viagens 0', 'Frete bruto R$ 0,00', 'Média bruta por viagem -', 'Frete bruto por km -', 'KM rodado 0 km',
                                     'Frete líquido R$ 0,00', 'Média líquida por viagem -', 'Frete líquido por km -'])
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
                                     'Frete líquido por km R$ 12,31'])
        expect(all('.counter-card .icon-success').size).to eq(3)
        expect(page).to have_no_css('.trips-table .text-danger')
        expect(page).to have_css('.chart-card', count: 6)
        expect(html_table_to_rows(table: find('.trips-table'))).to eq(
          [
            ['Motorista', 'Viagens', 'KM rodado', 'Frete bruto', 'Frete líquido', 'Média por viagem', 'Bruto/km', 'Líquido/km'],
            ['JOSE SILVA', '2', '650 km', 'R$ 9.000,00', 'R$ 8.000,00', 'R$ 4.500,00', 'R$ 13,85', 'R$ 12,31'],
            ['MARIA SOUZA', '1', '0 km', 'R$ 2.000,00', 'R$ 2.000,00', 'R$ 2.000,00', '-', '-'],
            ['Total', '3', '650 km', 'R$ 11.000,00', 'R$ 10.000,00', 'R$ 3.666,67', 'R$ 13,85', 'R$ 12,31'],
          ],
        )
        expect(page).to have_no_text('PEDRO OUTRO')
      end

      scenario 'groups the trips by vehicle keeping the period' do
        visit trips_path(october)
        click_on 'Veículo'

        expect(Atua::Manifest.count).to eq(4)
        expect(page).to have_current_path(/dimension=vehicle/)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1)).to eq(
          [
            ['AAA1A11', '2', '400 km', 'R$ 6.000,00', 'R$ 6.000,00', 'R$ 3.000,00', 'R$ 10,00', 'R$ 10,00'],
            ['BBB2B22', '1', '250 km', 'R$ 5.000,00', 'R$ 4.000,00', 'R$ 5.000,00', 'R$ 20,00', 'R$ 16,00'],
            ['Total', '3', '650 km', 'R$ 11.000,00', 'R$ 10.000,00', 'R$ 3.666,67', 'R$ 13,85', 'R$ 12,31'],
          ],
        )
      end

      scenario 'sorts the vehicles by the gross per km' do
        visit trips_path(october.merge(dimension: 'vehicle'))
        within('.trips-table thead') { click_on 'Bruto/km' }

        expect(Atua::Manifest.count).to eq(4)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(%w[BBB2B22 AAA1A11 Total])
      end

      scenario 'filters the trips by plate' do
        visit trips_path(october.merge(dimension: 'vehicle', plate: 'bbb2b22'))

        expect(Atua::Manifest.count).to eq(4)
        expect(html_table_to_rows(table: find('.trips-table')).drop(1).map(&:first)).to eq(%w[BBB2B22 Total])
      end
    end

    context 'when the trips dashboard is turned off for the tenant' do
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
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 500,
                  documents: [['74001', 1_000_000, 10, 'JOSE SILVA']])
      login_as(admin, scope: :user)
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
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 500,
                  documents: [['74001', 1_000_000, 10, 'JOSE SILVA']])
      login_as(admin, scope: :user)
    end

    scenario 'draws the monthly charts and keeps only the essential columns without scrolling sideways' do
      use_mobile_screen(width: 360)
      visit trips_path(october)

      expect(page).to have_css('.chart-card canvas', count: 4)
      expect(page).to have_css('.chart-card canvas', count: 6, visible: :all)
      expect(page).to have_css('th', text: /\AMotorista\z/i)
      expect(page).to have_css('th', text: /\AViagens\z/i)
      expect(page).to have_css('th', text: /\AFrete bruto\z/i)
      expect(page).to have_css('th', text: /\AFrete líquido\z/i)
      expect(page).to have_no_css('th', text: %r{\ABruto/km\z}i)
      expect(page).to have_no_css('th', text: /\AKM rodado\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      expect(page.evaluate_script('Object.values(Chartkick.charts)[0].getChartObject().data.labels')).to eq(['JOSE SILVA (1)'])
      expect(page.evaluate_script(
        'Object.values(Chartkick.charts).map((chart) => chart.getChartObject().data.datasets.map((dataset) => dataset.backgroundColor))',
      ).uniq).to eq([['#2563eb', '#dc3545']])
    end
  end
end
