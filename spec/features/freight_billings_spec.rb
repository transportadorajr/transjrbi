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

    context 'when there are no trips in the period' do
      scenario 'shows the empty state with zeroed indicators' do
        visit freight_billing_path(october)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 0,00', 'Frete líquido R$ 0,00', 'Viagens 0', 'Frete bruto por km -', 'Frete líquido por km -', 'KM rodado 0 km'],
        )
      end
    end

    context 'when there are trips and complements' do
      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:grouped_taker) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
      let!(:loose_taker) { create(:atua_customer, tenant:, code: 7200) }
      let!(:first_trip) { create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8)) }
      let!(:second_trip) { create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7)) }
      let!(:steel) do
        create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02',
                                         driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7100, origin_city: 'IPATINGA',
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

      scenario 'opens the current month from the intelligence menu' do
        travel_to(Date.new(2026, 10, 19)) do
          visit root_path
          within('.sidebar-desktop') do
            click_on 'Inteligência'
            click_on 'Faturamento de Fretes'
          end

          expect(page).to have_current_path(freight_billing_path)
          expect(page).to have_css('h1', text: 'Faturamento de Fretes')
          expect(page).to have_text('Saídas de 01/10/2026 a 31/10/2026')
          expect(page).to have_link('Conjunto', class: 'btn-primary')
        end
      end

      scenario 'shows the gross and net freight per truck and trailer' do
        visit freight_billing_path(october)

        expect(Atua::TransportDocument.count).to eq(5)
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Frete bruto R$ 20.000,00', 'Frete líquido R$ 19.350,00', 'Viagens 2', 'Frete bruto por km R$ 26,39',
           'Frete líquido por km R$ 25,49', 'KM rodado 720 km'],
        )
        expect(page).to have_text('Frete por Conjunto')
        expect(page).to have_text('Evolução Mensal')
        expect(page).to have_text('Frete bruto e líquido por mês de saída, de Mai/2026 a Out/2026')
        expect(html_table_to_rows).to eq(
          [
            ['Conjunto', 'Viagens', 'KM rodado', 'KM vazio', 'Frete bruto', 'Despesas de frete', 'Despesas', 'Frete líquido',
             'Bruto/km', 'Líquido/km', 'Participação'],
            ['RVR2C34 + RVR9C02', '1', '520 km', '80 km', 'R$ 15.000,00', 'R$ 500,00', 'R$ 150,00', 'R$ 14.350,00', 'R$ 28,85',
             'R$ 27,60', '75,0%'],
            ['RVR8J90', '1', '200 km', '0 km', 'R$ 5.000,00', 'R$ 0,00', 'R$ 0,00', 'R$ 5.000,00', 'R$ 20,00', 'R$ 20,00', '25,0%'],
            ['Total', '2', '720 km', '80 km', 'R$ 20.000,00', 'R$ 500,00', 'R$ 150,00', 'R$ 19.350,00', 'R$ 26,39', 'R$ 25,49',
             '100,0%'],
          ],
        )
        expect(page).to have_no_text('OUT1A11')
      end

      scenario 'groups the freight by driver keeping the period' do
        visit freight_billing_path(october)
        click_on 'Motorista'

        expect(page).to have_current_path(freight_billing_path(october.merge(dimension: 'driver')))
        expect(page).to have_link('Motorista', class: 'btn-primary')
        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 4, 7) }).to eq(
          [
            ['Motorista', 'Viagens', 'Frete bruto', 'Frete líquido'],
            ['JOSE SILVA', '1', 'R$ 15.000,00', 'R$ 14.350,00'],
            ['MARIA SOUZA', '1', 'R$ 5.000,00', 'R$ 5.000,00'],
            ['Total', '2', 'R$ 20.000,00', 'R$ 19.350,00'],
          ],
        )
      end

      scenario 'groups the freight by customer group' do
        visit freight_billing_path(october.merge(dimension: 'customer_group'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 1, 2, 4) }).to eq(
          [
            ['Grupo de clientes', 'Viagens', 'KM rodado', 'Frete bruto'],
            ['USIMINAS', '2', '720 km', 'R$ 15.000,00'],
            ['Sem grupo', '1', '520 km', 'R$ 5.000,00'],
            ['Total', '2', '720 km', 'R$ 20.000,00'],
          ],
        )
      end

      scenario 'groups the freight by origin' do
        visit freight_billing_path(october.merge(dimension: 'origin'))

        expect(html_table_to_rows.map { |row| row.values_at(0, 4, 10) }).to eq(
          [
            ['Origem', 'Frete bruto', 'Participação'],
            ['IPATINGA/MG', 'R$ 15.000,00', '75,0%'],
            ['BELO HORIZONTE/MG', 'R$ 5.000,00', '25,0%'],
            ['Total', 'R$ 20.000,00', '100,0%'],
          ],
        )
      end

      scenario 'filters by plate and customer group' do
        visit freight_billing_path(october)
        fill_in 'Placa', with: 'rvr-8j90'
        select 'USIMINAS', from: 'Grupo de clientes'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.map(&:first)).to eq(%w[Conjunto RVR8J90 Total])
        expect(first('.counter-card').text.squish).to eq('Frete bruto R$ 5.000,00')
      end

      scenario 'filters by another period' do
        visit freight_billing_path(october)
        fill_in 'Saídas a partir de', with: '2026-10-05'
        fill_in 'Saídas até', with: '2026-10-31'
        click_on 'Aplicar Filtros'

        expect(page).to have_text('Saídas de 05/10/2026 a 31/10/2026')
        expect(html_table_to_rows.map(&:first)).to eq(%w[Conjunto RVR8J90 Total])
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
      expect(page).to have_no_css('th', text: /\AKM vazio\z/i)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
