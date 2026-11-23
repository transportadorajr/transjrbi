require 'rails_helper'

describe 'Goals panel', flipper: { revenue_goals: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Painel de metas', slug: 'goals', writable: false) }
  let!(:goals_resource) { create(:resource, name: 'Metas de faturamento', slug: 'revenue_goals') }
  let(:month) { Date.new(2026, 11, 1) }

  def freight(tenant, plate, freight_cents, issued_at: Time.zone.local(2026, 11, 5, 10), taker: nil, macro_region: nil, **)
    create(:atua_transport_document, tenant:, plate:, freight_cents:, issued_at:, taker_code: taker&.code, origin_macro_region: macro_region, **)
  end

  def taker(tenant, customer_group)
    create(:atua_customer, tenant:, customer_group:)
  end

  def card_texts
    all('#goal_company_cards .counter-card').map { it.text.squish }
  end

  before { travel_to(Time.zone.local(2026, 11, 10, 10)) }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit goals_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'with the goals and the billing of the month' do
      before do
        create(:own_fleet, tenant:, plates: %w[AJR4391 RHJ5A50 QWE1A23])
        create(:revenue_goal, tenant:, month:, amount_cents: 10_000_000)
        create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391', amount_cents: 1_000_000)
        create(:revenue_goal, :vehicle, tenant:, month:, plate: 'RHJ5A50', amount_cents: 2_000_000)
        usiminas = create(:customer_group, tenant:, name: 'USIMINAS')
        arcelor = create(:customer_group, tenant:, name: 'ARCELOR')
        create(:customer_group, tenant:, name: 'GERDAU', activated_at: nil)
        create(:revenue_goal, :customer_group, tenant:, month:, customer_group: usiminas, amount_cents: 6_000_000)
        region = create(:macro_region, tenant:, name: 'VALE DO AÇO/MG')
        create(:revenue_goal, :region, tenant:, month:, macro_region: region, amount_cents: 5_000_000)
        freight(tenant, 'AJR4391', 900_000, taker: taker(tenant, usiminas), macro_region: region)
        freight(tenant, 'RHJ5A50', 400_000, issued_at: Time.zone.local(2026, 11, 9, 8), taker: taker(tenant, arcelor))
        freight(tenant, 'XYZ9K87', 250_000)
        freight(tenant, 'AJR4391', 999_999, issued_at: Time.zone.local(2026, 10, 31, 23))
        freight(other_tenant, 'AJR4391', 7_777_700)
        create(:revenue_goal, tenant: other_tenant, month:, amount_cents: 1_000)
      end

      scenario 'compares the billing of the company and of each customer group with the goals from the menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Metas e projeções'
          click_on 'Metas'
        end

        expect(page).to have_current_path(goals_path)
        expect(page).to have_css('h1.page-title', text: 'Metas')
        expect(card_texts).to eq(
          ['Meta do mês R$ 100.000,00', 'Faturado no mês R$ 15.500,00', 'Falta para a meta R$ 84.500,00', 'Atingimento 15,5%',
           'Projeção de fechamento R$ 48.437,50', 'Ritmo necessário por dia útil R$ 4.970,59'],
        )
        expect(page).to have_css('progress.goal-progress-danger[value="1550000"][max="10000000"]')
        expect(page).to have_text('Projeção pelo ritmo atual, com 8 de 25 dias úteis do mês já decorridos.')
        expect(page).to have_text('Semana de 08/11 a 14/11')
        expect(all('#goal_week_cards .counter-card').map { it.text.squish }).to eq(
          ['Meta da semana R$ 24.000,00', 'Faturado na semana R$ 4.000,00', 'Falta para a meta R$ 20.000,00', 'Atingimento 16,7%'],
        )
        expect(page).to have_css('#goal_chart', text: 'Faturado x previsto no mês')
        expect(page).to have_css('#goal_dimension_bar .btn-primary', text: 'Clientes')
        expect(page).to have_css('#goal_customer_groups .table-card-title', text: 'Metas por grupo de clientes')
        expect(page).to have_no_css('#goal_vehicles_table')
        expect(page).to have_no_css('#goal_regions_table')
        expect(html_table_to_rows(table: find_by_id('goal_customer_groups_table'))).to eq(
          [
            ['Grupo de clientes', 'Meta', 'Faturado', 'Atingimento', 'Meta da semana', 'Faturado na semana', 'Atingimento na semana', 'Situação', 'Projeções'],
            ['USIMINAS', 'R$ 60.000,00', 'R$ 9.000,00', '15,0%', 'R$ 14.400,00', 'R$ 0,00', '0,0%', 'Abaixo da meta', ''],
            ['ARCELOR', 'Sem meta', 'R$ 4.000,00', 'Sem meta', 'Sem meta', 'R$ 4.000,00', 'Sem meta', 'Sem meta', ''],
            ['Sem grupo de clientes', 'Sem meta', 'R$ 2.500,00', 'Sem meta', 'Sem meta', 'R$ 0,00', 'Sem meta', 'Sem meta', ''],
          ],
        )
        expect(page).to have_no_link(href: /revenue_projection_history/)
        expect(RevenueGoal.where(tenant:).count).to eq(5)
        expect(CustomerGroup.where(tenant:).count).to eq(3)
      end

      scenario 'shows the ranking of the vehicles when they are selected' do
        visit goals_path
        within('#goal_dimension_bar') { click_on 'Veículo' }

        expect(page).to have_current_path(goals_path(dimension: 'vehicle'))
        expect(page).to have_css('#goal_dimension_bar .btn-primary', text: 'Veículo')
        expect(page).to have_css('#goal_vehicles .table-card-title', text: 'Ranking dos veículos')
        expect(page).to have_no_css('#goal_customer_groups_table')
        expect(html_table_to_rows).to eq(
          [
            ['#', 'Placa', 'Meta', 'Faturado', 'Falta', 'Atingimento', 'Projeção', 'Situação', 'Projeções'],
            ['1', 'AJR4391', 'R$ 10.000,00', 'R$ 9.000,00', 'R$ 1.000,00', '90,0%', 'R$ 28.125,00', 'No ritmo', ''],
            ['2', 'RHJ5A50', 'R$ 20.000,00', 'R$ 4.000,00', 'R$ 16.000,00', '20,0%', 'R$ 12.500,00', 'Abaixo da meta', ''],
            ['3', 'QWE1A23', 'Sem meta', 'R$ 0,00', 'Sem meta', 'Sem meta', 'R$ 0,00', 'Sem meta', ''],
            ['', 'Terceiro', 'Sem meta', 'R$ 2.500,00', 'Sem meta', 'Sem meta', 'R$ 7.812,50', 'Sem meta', ''],
          ],
        )
        expect(page).to have_css('#goal_vehicles_table .goal-plate', text: 'AJR4391')
      end

      scenario 'shows the macro regions when they are selected and keeps the choice across the months' do
        visit goals_path
        within('#goal_dimension_bar') { click_on 'Região' }

        expect(page).to have_current_path(goals_path(dimension: 'macro_region'))
        expect(page).to have_css('#goal_regions .table-card-title', text: 'Metas por macro região')
        expect(html_table_to_rows).to eq(
          [
            ['Macro região', 'Meta', 'Faturado', 'Atingimento', 'Meta da semana', 'Faturado na semana', 'Atingimento na semana', 'Situação', 'Projeções'],
            ['VALE DO AÇO/MG', 'R$ 50.000,00', 'R$ 9.000,00', '18,0%', 'R$ 12.000,00', 'R$ 0,00', '0,0%', 'Abaixo da meta', ''],
            ['Sem macro região', 'Sem meta', 'R$ 6.500,00', 'Sem meta', 'Sem meta', 'R$ 4.000,00', 'Sem meta', 'Sem meta', ''],
          ],
        )

        click_on 'Mês anterior'

        expect(page).to have_current_path(goals_path(dimension: 'macro_region', month: '2026-10'))
        expect(html_table_to_rows.drop(1)).to eq([['Sem macro região', 'Sem meta', 'R$ 9.999,99', 'Sem meta', '-', '-', '-', 'Sem meta', '']])
      end

      scenario 'does not offer the drivers as a grouping' do
        visit goals_path

        within('#goal_dimension_bar') { expect(page).to have_no_link('Motorista') }

        visit goals_path(dimension: 'driver')

        expect(page).to have_current_path(goals_path)
        expect(page).to have_text('Agrupar por não está incluído na lista')
      end

      scenario 'redirects an unknown grouping back to the panel' do
        visit goals_path(dimension: 'product_group')

        expect(page).to have_current_path(goals_path)
        expect(page).to have_text('Agrupar por não está incluído na lista')
      end

      scenario 'ranks the vehicles by the goal achievement' do
        visit goals_path(dimension: 'vehicle')
        within('#goal_vehicles_table thead') { click_on 'Placa' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[AJR4391 QWE1A23 RHJ5A50 Terceiro])

        within('#goal_vehicles_table thead') { click_on 'Atingimento' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[AJR4391 RHJ5A50 QWE1A23 Terceiro])

        within('#goal_vehicles_table thead') { click_on 'Atingimento' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[QWE1A23 RHJ5A50 AJR4391 Terceiro])
      end

      context 'with a vehicle close to its goal' do
        before do
          create(:revenue_goal, :vehicle, tenant:, month:, plate: 'QWE1A23', amount_cents: 3_000_000)
          freight(tenant, 'QWE1A23', 900_000)
        end

        scenario 'ranks the vehicles by the status from the best to the worst' do
          visit goals_path(dimension: 'vehicle')
          within('#goal_vehicles_table thead') { click_on 'Situação' }

          expect(page).to have_current_path(goals_path(dimension: 'vehicle', sort: 'status', direction: 'desc'))
          expect(html_table_to_rows.drop(1).map { [it[1], it[7]] }).to eq(
            [['AJR4391', 'No ritmo'], ['QWE1A23', 'Atenção'], ['RHJ5A50', 'Abaixo da meta'], ['Terceiro', 'Sem meta']],
          )

          within('#goal_vehicles_table thead') { click_on 'Situação' }

          expect(html_table_to_rows.drop(1).map { [it[1], it[7]] }).to eq(
            [['RHJ5A50', 'Abaixo da meta'], ['QWE1A23', 'Atenção'], ['AJR4391', 'No ritmo'], ['Terceiro', 'Sem meta']],
          )
          expect(RevenueGoal.where(tenant:, target_type: 'vehicle').count).to eq(3)
        end
      end

      context 'with trailers in the own fleet' do
        before do
          tenant.own_fleet.update!(plates: %w[AJR4391 RHJ5A50 QWE1A23 RHJ5A51 QWE1A24])
          create(:atua_vehicle, tenant:, plate: 'RHJ5A51', category: 'Carreta')
          create(:atua_vehicle, tenant:, plate: 'QWE1A24', category: 'Carreta')
          create(:revenue_goal, :trailer, tenant:, month:, plate: 'RHJ5A51', amount_cents: 500_000)
          freight(tenant, 'AJR4391', 300_000, trailer_plate: 'RHJ5A51')
          freight(tenant, 'RHJ5A50', 100_000, trailer_plate: 'TRC9X99')
          freight(other_tenant, 'AJR4391', 5_000_000, trailer_plate: 'RHJ5A51')
        end

        scenario 'shows only the trucks ranking without a trailers tab' do
          visit goals_path(dimension: 'vehicle', vehicle_type: 'trailer')

          expect(page).to have_current_path(goals_path(dimension: 'vehicle', vehicle_type: 'trailer'))
          expect(page).to have_no_css('#goal_vehicle_type_nav')
          expect(page).to have_no_css('#goal_trailers')
          expect(page).to have_css('#goal_vehicles .table-card-title', text: 'Ranking dos veículos')
          expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[AJR4391 RHJ5A50 QWE1A23 Terceiro])
          expect(RevenueGoal.where(tenant:, target_type: 'trailer').count).to eq(1)
        end
      end

      context 'with the revenue projection enabled', flipper: { revenue_goals: :tenant, revenue_projection: :tenant } do
        let!(:projection_resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }

        scenario 'links each vehicle, customer group and region to its projection history' do
          visit goals_path(dimension: 'vehicle')

          within('#goal_vehicles_table') { click_on 'Ver a projeção de AJR4391' }

          expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-30', plate: 'AJR4391'))
          expect(page).to have_css('h1.page-title', text: 'Histórico da projeção')

          visit goals_path
          within('#goal_customer_groups_table') { click_on 'Ver a projeção de USIMINAS' }

          usiminas = tenant.customer_groups.find_by!(name: 'USIMINAS')
          expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-30', customer_group_id: usiminas.id))

          visit goals_path(dimension: 'macro_region')
          within('#goal_regions_table') { click_on 'Ver a projeção de Sem macro região' }

          expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-30', macro_region_id: 'others'))
          expect(page).to have_no_link('Ver a projeção de Terceiro')
        end
      end

      scenario 'shows the closed previous month without goals' do
        visit goals_path
        click_on 'Mês anterior'

        expect(page).to have_current_path(goals_path(month: '2026-10'))
        expect(card_texts).to eq(
          ['Meta do mês Sem meta', 'Faturado no mês R$ 9.999,99', 'Falta para a meta Sem meta', 'Atingimento Sem meta',
           'Projeção de fechamento R$ 9.999,99', 'Ritmo necessário por dia útil Sem meta'],
        )
        expect(page).to have_text('A meta da transportadora deste mês ainda não foi cadastrada.')
        expect(page).to have_text('Mês encerrado. A projeção é o próprio faturado.')
        expect(page).to have_no_css('#goal_week')
        expect(html_table_to_rows(table: find_by_id('goal_customer_groups_table'))[1]).to eq(
          ['ARCELOR', 'Sem meta', 'R$ 0,00', 'Sem meta', '-', '-', '-', 'Sem meta', ''],
        )

        within('#goal_missing_note') { click_on 'Cadastrar metas' }

        expect(page).to have_current_path(revenue_goals_path(month: '2026-10'))
      end
    end

    context 'with more vehicles than a page' do
      let(:plates) { (1..12).map { format('AAA%04d', it) } }

      before do
        create(:own_fleet, tenant:, plates:)
        plates.each_with_index { |plate, index| freight(tenant, plate, (index + 1) * 10_000) }
        freight(tenant, 'XYZ9K87', 5_000)
      end

      scenario 'pages the ranking and shows the third party line on the last page' do
        visit goals_path(dimension: 'vehicle')

        expect(html_table_to_rows.drop(1).map { it.first(2) }).to eq((1..10).map { [it.to_s, plates[12 - it]] })
        expect(page).to have_no_css('#goal_vehicles_table td', text: 'Terceiro')

        within('#goal_vehicles .table-pagination') { click_on '2' }

        expect(page).to have_current_path(goals_path(dimension: 'vehicle', page: 2))
        expect(html_table_to_rows.drop(1).map { it.first(2) }).to eq([['11', plates[1]], ['12', plates[0]], ['', 'Terceiro']])
        expect(card_texts.second).to eq('Faturado no mês R$ 7.850,00')
      end

      scenario 'goes back to the first page and the default order when the grouping changes' do
        visit goals_path(dimension: 'vehicle', sort: 'label', direction: 'asc', page: 2)

        within('#goal_dimension_bar') { click_on 'Clientes' }

        expect(page).to have_current_path(goals_path(dimension: 'customer_group'))

        within('#goal_dimension_bar') { click_on 'Veículo' }

        expect(page).to have_current_path(goals_path(dimension: 'vehicle'))
        expect(html_table_to_rows.drop(1).map { it.first(2) }).to eq((1..10).map { [it.to_s, plates[12 - it]] })
      end
    end

    scenario 'shows an empty ranking without an own fleet' do
      visit goals_path(dimension: 'vehicle')

      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_css('#goal_vehicles_table')
    end

    context 'with truck groups and their goals' do
      before do
        create(:own_fleet, tenant:, plates: %w[AJR4391 BRA2E19 RHJ5A50])
        create(:truck_group, tenant:, name: 'SIDER', axles: [], plates: %w[RHJ5A50])
        nine_axles = create(:truck_group, tenant:, name: '9 EIXO NACIONAL', axles: [9])
        create(:revenue_goal, :truck_group, tenant:, month:, truck_group: nine_axles, amount_cents: 16_000_000)
        freight(tenant, 'AJR4391', 18_000_000, axles: 9, issued_at: Time.zone.local(2026, 10, 10, 10))
        freight(tenant, 'BRA2E19', 12_000_000, axles: 9, issued_at: Time.zone.local(2026, 9, 10, 10))
        freight(tenant, 'RHJ5A50', 9_000_000, issued_at: Time.zone.local(2026, 10, 14, 10))
        freight(tenant, 'AJR4391', 4_000_000, axles: 9)
        freight(other_tenant, 'AJR4391', 99_000_000, axles: 9)
      end

      scenario 'compares the average billing per truck of each group in the last months with the goal' do
        visit goals_path

        expect(TruckGroup.where(tenant:).count).to eq(2)
        within('#goal_truck_groups') do
          expect(page).to have_text('Média por caminhão dos grupos')
          expect(html_table_to_rows(table: find_by_id('goal_truck_groups_table'))).to eq(
            [
              ['Grupo de caminhões', 'Caminhões', 'Agosto de 2026', 'Setembro de 2026', 'Outubro de 2026', 'Novembro de 2026', 'Meta'],
              ['9 EIXO NACIONAL', '2', '-', 'R$ 120.000,00', 'R$ 90.000,00', 'R$ 20.000,00', 'R$ 160.000,00'],
              ['SIDER', '1', 'R$ 0,00', 'R$ 0,00', 'R$ 90.000,00', 'R$ 0,00', 'Sem meta'],
              ['Total geral', '3', 'R$ 0,00', 'R$ 60.000,00', 'R$ 90.000,00', 'R$ 13.333,33', '-'],
            ],
          )
          expect(page).to have_css("#goal_truck_group_#{TruckGroup.find_by!(name: '9 EIXO NACIONAL').id} .text-danger", text: 'R$ 90.000,00')
        end
      end
    end

    scenario 'does not show the truck groups without any truck group' do
      visit goals_path

      expect(page).to have_css('#goal_company_cards')
      expect(page).to have_no_css('#goal_truck_groups')
    end

    scenario 'redirects an invalid month back to the current month' do
      visit goals_path(month: '2026-13')

      expect(page).to have_current_path(goals_path)
      expect(page).to have_text('Mês não é válido')
    end
  end

  context 'when an admin can only read the panel' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:access, user: admin, resource:, reads: true)
      login_as(admin, scope: :user)
    end

    scenario 'does not link to the goals registration' do
      visit goals_path

      expect(page).to have_css('h1.page-title', text: 'Metas')
      expect(page).to have_no_link('Cadastrar metas')
    end
  end

  context 'when the flag is off for the tenant' do
    let!(:other_owner) { create(:user, tenant: other_tenant, user_type: :owner) }

    before { login_as(other_owner, scope: :user) }

    scenario 'answers not found' do
      visit goals_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:own_fleet, tenant:, plates: %w[AJR4391])
      create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391', amount_cents: 1_000_000)
      usiminas = create(:customer_group, tenant:, name: 'USIMINAS')
      create(:revenue_goal, :customer_group, tenant:, month:, customer_group: usiminas, amount_cents: 3_000_000)
      freight(tenant, 'AJR4391', 900_000, taker: taker(tenant, usiminas))
      login_as(owner, scope: :user)
    end

    scenario 'keeps the essential columns and does not scroll sideways' do
      visit goals_path
      use_mobile_screen(width: 360)

      expect(page).to have_css('#goal_customer_groups_table td', text: '30,0%', visible: :visible)
      expect(page).to have_no_css('#goal_customer_groups_table th', text: 'META DA SEMANA', visible: :visible)
      expect(page).to have_no_css('#goal_customer_groups .dropdown-toggle', text: 'Ordenar por')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      within('#goal_dimension_bar') { click_on 'Veículo' }

      expect(page).to have_css('#goal_vehicles_table td', text: '90,0%', visible: :visible)
      expect(page).to have_no_css('#goal_vehicles_table th', text: 'FATURADO', visible: :visible)
      expect(page).to have_css('#goal_vehicles .dropdown-toggle', text: 'Ordenar por', visible: :visible)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'keeps only the month and the goal of the truck groups on a phone' do
      create(:truck_group, tenant:, name: 'SIDER', axles: [], plates: %w[AJR4391])
      visit goals_path
      use_mobile_screen(width: 360)

      expect(page).to have_css('#goal_truck_groups_table th', text: 'NOVEMBRO DE 2026', visible: :visible)
      expect(page).to have_no_css('#goal_truck_groups_table th', text: 'OUTUBRO DE 2026', visible: :visible)
      expect(page).to have_css('#goal_truck_groups_table td', text: 'R$ 9.000,00', visible: :visible)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
