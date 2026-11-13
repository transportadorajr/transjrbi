require 'rails_helper'

describe 'Goals panel', flipper: { revenue_goals: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Painel de metas', slug: 'goals', writable: false) }
  let!(:goals_resource) { create(:resource, name: 'Metas de faturamento', slug: 'revenue_goals') }
  let(:month) { Date.new(2026, 11, 1) }

  def freight(tenant, plate, freight_cents, issued_at: Time.zone.local(2026, 11, 5, 10))
    create(:atua_transport_document, tenant:, plate:, freight_cents:, issued_at:)
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
        freight(tenant, 'AJR4391', 900_000)
        freight(tenant, 'RHJ5A50', 400_000)
        freight(tenant, 'XYZ9K87', 250_000)
        freight(tenant, 'AJR4391', 999_999, issued_at: Time.zone.local(2026, 10, 31, 23))
        freight(other_tenant, 'AJR4391', 7_777_700)
        create(:revenue_goal, tenant: other_tenant, month:, amount_cents: 1_000)
      end

      scenario 'compares the billing of the company and of each vehicle with the goals from the menu' do
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
        expect(html_table_to_rows).to eq(
          [
            ['#', 'Placa', 'Meta', 'Faturado', 'Falta', 'Atingimento', 'Projeção', 'Situação'],
            ['1', 'AJR4391', 'R$ 10.000,00', 'R$ 9.000,00', 'R$ 1.000,00', '90,0%', 'R$ 28.125,00', 'No ritmo'],
            ['2', 'RHJ5A50', 'R$ 20.000,00', 'R$ 4.000,00', 'R$ 16.000,00', '20,0%', 'R$ 12.500,00', 'Abaixo da meta'],
            ['3', 'QWE1A23', 'Sem meta', 'R$ 0,00', 'Sem meta', 'Sem meta', 'R$ 0,00', 'Sem meta'],
            ['', 'Terceiro', 'Sem meta', 'R$ 2.500,00', 'Sem meta', 'Sem meta', 'R$ 7.812,50', 'Sem meta'],
          ],
        )
        expect(RevenueGoal.where(tenant:).count).to eq(3)
      end

      scenario 'ranks the vehicles by the goal achievement' do
        visit goals_path
        within('#goal_vehicles_table thead') { click_on 'Placa' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[AJR4391 QWE1A23 RHJ5A50 Terceiro])

        within('#goal_vehicles_table thead') { click_on 'Atingimento' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[AJR4391 RHJ5A50 QWE1A23 Terceiro])

        within('#goal_vehicles_table thead') { click_on 'Atingimento' }

        expect(html_table_to_rows.drop(1).map { it[1] }).to eq(%w[QWE1A23 RHJ5A50 AJR4391 Terceiro])
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

        within('#goal_missing_note') { click_on 'Cadastrar metas' }

        expect(page).to have_current_path(revenue_goals_path(month: '2026-10'))
      end
    end

    scenario 'shows an empty ranking without an own fleet' do
      visit goals_path

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
      freight(tenant, 'AJR4391', 900_000)
      login_as(owner, scope: :user)
    end

    scenario 'keeps the essential columns and does not scroll sideways' do
      visit goals_path
      use_mobile_screen(width: 360)

      expect(page).to have_css('#goal_vehicles_table td', text: '90,0%', visible: :visible)
      expect(page).to have_no_css('#goal_vehicles_table th', text: 'FATURADO', visible: :visible)
      expect(page).to have_css('#goal_vehicles .dropdown-toggle', text: 'Ordenar por', visible: :visible)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
