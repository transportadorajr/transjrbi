require 'rails_helper'

describe 'Goals panel', flipper: { revenue_goals: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Painel de metas', slug: 'goals', writable: true) }
  let!(:goals_resource) { create(:resource, name: 'Metas de faturamento', slug: 'revenue_goals') }
  let(:month) { Date.new(2026, 11, 1) }

  def freight(tenant, plate, freight_cents, issued_at: Time.zone.local(2026, 11, 5, 10), taker: nil, macro_region: nil)
    create(:atua_transport_document, tenant:, plate:, freight_cents:, issued_at:, taker_code: taker&.code, origin_macro_region: macro_region)
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

      scenario 'shows the drivers when they are selected' do
        create(:revenue_goal, :driver, tenant:, month:, driver_code: 11, amount_cents: 3_000_000)
        create(:atua_transport_document, tenant:, plate: 'AJR4391', driver_code: 11, driver_name: 'JOSE DA SILVA', freight_cents: 600_000,
                                         issued_at: Time.zone.local(2026, 11, 6, 10))

        visit goals_path
        within('#goal_dimension_bar') { click_on 'Motorista' }

        expect(page).to have_current_path(goals_path(dimension: 'driver'))
        expect(page).to have_css('#goal_drivers .table-card-title', text: 'Metas por motorista')
        expect(html_table_to_rows).to eq(
          [
            ['Motorista', 'Meta', 'Faturado', 'Atingimento', 'Meta da semana', 'Faturado na semana', 'Atingimento na semana', 'Situação', 'Projeções'],
            ['JOSE DA SILVA', 'R$ 30.000,00', 'R$ 6.000,00', '20,0%', 'R$ 7.200,00', 'R$ 0,00', '0,0%', 'Abaixo da meta', ''],
          ],
        )
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
    end

    scenario 'shows an empty ranking without an own fleet' do
      visit goals_path(dimension: 'vehicle')

      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_css('#goal_vehicles_table')
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

  context 'when an admin can edit the panel' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:access, user: admin, resource:, reads: true, creates: true)
      login_as(admin, scope: :user)
    end

    scenario 'reaches the goals registration from the panel' do
      visit goals_path(month: '2026-10')

      within('.page-header') { click_on 'Cadastrar metas' }

      expect(page).to have_current_path(revenue_goals_path(month: '2026-10'))
      expect(page).to have_css('h1.page-title', text: 'Metas de faturamento')
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
  end
end
