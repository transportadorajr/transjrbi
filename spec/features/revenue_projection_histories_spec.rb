require 'rails_helper'

describe 'Revenue projection history', flipper: { revenue_projection: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }
  let!(:notes_resource) { create(:resource, name: 'Anotações da projeção', slug: 'revenue_projection_notes', writable: true) }

  before { travel_to(Time.zone.local(2026, 11, 4, 10)) }

  def snapshot(tenant, taken_on, projected_cents, period_type: 'month', **)
    period = period_type == 'month' ? taken_on.all_month : taken_on.all_week(:sunday)
    create(:revenue_projection_snapshot, tenant:, period_type:, period_start: period.first, period_end: period.last, taken_on:,
                                         reference_at: taken_on.in_time_zone.change(hour: 5), projected_cents:, low_cents: projected_cents,
                                         high_cents: projected_cents, **)
  end

  def build_history(tenant)
    snapshot(tenant, Date.new(2026, 10, 1), 2_000_000)
    snapshot(tenant, Date.new(2026, 11, 1), 2_300_000, reconstructed: true)
    snapshot(tenant, Date.new(2026, 11, 2), 2_310_000, reconstructed: true)
    snapshot(tenant, Date.new(2026, 11, 4), 2_330_000)
    snapshot(tenant, Date.new(2026, 11, 1), 0, period_type: 'week', days: [
               { date: '2026-11-02', realized_cents: 0, expected_cents: 30_000 }, { date: '2026-11-03', realized_cents: 0, expected_cents: 100_000 },
               { date: '2026-11-07', realized_cents: 0, expected_cents: 50_000 }
             ])
    [[1, 0, 0, 'regular'], [2, 40_000, 2, 'weekday_holiday'], [3, 120_000, 5, 'regular']].each do |day, billed_cents, documents_count, day_type|
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 11, day), billed_cents:, documents_count:, day_type:)
    end
    [[1, 0, 'regular'], [2, 30_000, 'weekday_holiday'], [3, 100_000, 'regular']].each do |day, forecast_cents, day_type|
      create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, day), forecast_cents:, day_type:)
    end
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit revenue_projection_history_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'with the snapshots of the month' do
      before do
        build_history(tenant)
        snapshot(other_tenant, Date.new(2026, 11, 4), 9_900_000)
      end

      scenario 'compares the projection with the billing day by day and week by week from the intelligence menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Inteligência'
          click_on 'Histórico da projeção'
        end

        expect(page).to have_current_path(revenue_projection_history_path)
        expect(page).to have_css('h1.page-title', text: 'Histórico da projeção')
        expect(page).to have_no_link('Exportar Excel')
        expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Mensal')
        expect(page).to have_select('Mês', selected: 'Novembro de 2026', options: ['Novembro de 2026', 'Outubro de 2026'])
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['Projeção na abertura (01/11) R$ 23.000,00', 'Projeção atual (04/11) R$ 23.300,00', 'Faturado até 03/11 R$ 1.600,00',
           'Variação da projeção desde a abertura +R$ 300,00 (+1,3%)'],
        )
        expect(page).to have_text('O mês ainda está em andamento; o faturado considera só os dias já encerrados.')
        expect(page).to have_text('As projeções de 01/11 a 02/11 foram reconstruídas a partir do histórico')
        expect(page).to have_text('Evolução da projeção do mês')
        expect(html_table_to_rows(table: find_by_id('history_weeks'))).to eq(
          [['Semana', 'AberturaProjeção na abertura', 'Soma das previsões diárias', 'Faturado', 'Diferença', 'Situação'],
           ['01/11 a 07/11', 'R$ 1.800,00', 'R$ 1.300,00', 'R$ 1.600,00', '-', 'Em andamento']],
        )
        expect(html_table_to_rows(table: find_by_id('history_days'))).to eq(
          [['Dia', 'Previsto', 'Faturado', 'Diferença', 'CT-es', 'Projeção do mês na manhã', 'Ações'],
           ['01/11 dom', 'R$ 0,00', 'R$ 0,00', '+R$ 0,00', '0', 'R$ 23.000,00', ''],
           ['02/11 seg Feriado em dia útil', 'R$ 300,00', 'R$ 400,00 +33,3%', '+R$ 100,00 (+33,3%)', '2', 'R$ 23.100,00', ''],
           ['03/11 ter', 'R$ 1.000,00', 'R$ 1.200,00 +20,0%', '+R$ 200,00 (+20,0%)', '5', '-', '']],
        )
        expect(RevenueProjection::Snapshot.where(tenant:).month.count).to eq(4)
      end

      scenario 'chooses a previous closed month', :js do
        visit revenue_projection_history_path
        select 'Outubro de 2026', from: 'Mês'

        expect(page).to have_current_path(revenue_projection_history_path(period: 'month', start: '2026-10-01'))
        expect(page).to have_select('Mês', selected: 'Outubro de 2026')
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['PROJEÇÃO NA ABERTURA (01/10) R$ 20.000,00', 'ÚLTIMA PROJEÇÃO (01/10) R$ 20.000,00', 'FATURADO NO MÊS R$ 0,00',
           'FATURADO X PROJEÇÃO NA ABERTURA -R$ 20.000,00 (-100,0%)'],
        )
        expect(page).to have_text('A projeção não chegou a ficar a menos de 5% do faturado.')
        expect(page).to have_no_text('reconstruídas')
      end

      scenario 'switches to the history of the weeks' do
        visit revenue_projection_history_path
        click_on 'Semanal'

        expect(page).to have_current_path(revenue_projection_history_path(period: 'week'))
        expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Semanal')
        expect(page).to have_select('Semana', selected: '01/11 a 07/11/2026', options: ['01/11 a 07/11/2026'])
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['Projeção na abertura (01/11) R$ 0,00', 'Projeção atual (01/11) R$ 0,00', 'Faturado até 03/11 R$ 1.600,00',
           'Variação da projeção desde a abertura +R$ 0,00'],
        )
        expect(page).to have_text('A semana ainda está em andamento; o faturado considera só os dias já encerrados.')
        expect(page).to have_text('Evolução da projeção da semana')
        expect(page).to have_no_table('history_weeks')
        expect(html_table_to_rows(table: find_by_id('history_days'))).to eq(
          [['Dia', 'Previsto', 'Faturado', 'Diferença', 'CT-es', 'Projeção da semana na manhã', 'Ações'],
           ['01/11 dom', 'R$ 0,00', 'R$ 0,00', '+R$ 0,00', '0', 'R$ 0,00', ''],
           ['02/11 seg Feriado em dia útil', 'R$ 300,00', 'R$ 400,00 +33,3%', '+R$ 100,00 (+33,3%)', '2', '-', ''],
           ['03/11 ter', 'R$ 1.000,00', 'R$ 1.200,00 +20,0%', '+R$ 200,00 (+20,0%)', '5', '-', '']],
        )
        expect(RevenueProjection::Snapshot.where(tenant:).week.count).to eq(1)

        click_on 'Mensal'

        expect(page).to have_select('Mês', selected: 'Novembro de 2026')
      end
    end

    scenario 'tells that there is no history yet', flipper: { revenue_projection: :tenant, xlsx_export: :tenant } do
      visit revenue_projection_history_path

      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_css('#history_cards')
      expect(page).to have_no_link('Exportar Excel')
    end
  end

  context 'when the owner writes the notes of the days', :js do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before do
      build_history(tenant)
      login_as(owner, scope: :user)
    end

    scenario 'writes a note explaining a day' do
      visit revenue_projection_history_path
      find_by_id('history_days').find('tr', text: '02/11 seg').click_on('Anotar o dia 02/11/2026')

      within('#revenue_projection_day_note_modal') do
        expect(page).to have_text('Anotação de 02/11/2026 (segunda-feira)')
        fill_in 'Anotação', with: 'Greve no porto parou o carregamento'

        expect { click_on 'Salvar anotação' }.to change(RevenueProjection::DayNote, :count).by(1)
      end

      expect(page).to have_text('Anotação salva.')
      expect(page).to have_current_path(revenue_projection_history_path(period: 'month', start: '2026-11-01'))
      expect(page).to have_css('#history_days .history-note-row', text: 'Greve no porto parou o carregamento — Bruna Dona')
      note = RevenueProjection::DayNote.last
      expect(note).to have_attributes(tenant:, user: owner, date: Date.new(2026, 11, 2), body: 'Greve no porto parou o carregamento')
    end

    context 'with a note already written' do
      let!(:note) { create(:revenue_projection_day_note, tenant:, user: owner, date: Date.new(2026, 11, 3), body: 'Chuva na usina') }

      scenario 'erases the note leaving it blank' do
        visit revenue_projection_history_path
        expect(page).to have_css('#history_days .history-note-row', text: 'Chuva na usina — Bruna Dona')

        find_by_id('history_days').find('tr', text: '03/11 ter').click_on('Anotar o dia 03/11/2026')
        within('#revenue_projection_day_note_modal') do
          expect(page).to have_field('Anotação', with: 'Chuva na usina')
          fill_in 'Anotação', with: ''

          expect { click_on 'Salvar anotação' }.to change(RevenueProjection::DayNote, :count).by(-1)
        end

        expect(page).to have_text('Anotação salva.')
        expect(page).to have_no_css('#history_days .history-note-row')
      end
    end

    scenario 'writes a note from the history of the week and stays on it' do
      visit revenue_projection_history_path(period: 'week')
      find_by_id('history_days').find('tr', text: '03/11 ter').click_on('Anotar o dia 03/11/2026')

      within('#revenue_projection_day_note_modal') do
        fill_in 'Anotação', with: 'Chuva na usina'

        expect { click_on 'Salvar anotação' }.to change(RevenueProjection::DayNote, :count).by(1)
      end

      expect(page).to have_text('Anotação salva.')
      expect(page).to have_current_path(revenue_projection_history_path(period: 'week', start: '2026-11-01'))
      expect(page).to have_select('Semana', selected: '01/11 a 07/11/2026')
      expect(RevenueProjection::DayNote.last).to have_attributes(date: Date.new(2026, 11, 3), body: 'Chuva na usina')
    end
  end

  context 'when a user who only reads the projection is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }

    before do
      build_history(tenant)
      create(:revenue_projection_day_note, tenant:, date: Date.new(2026, 11, 2), body: 'Greve no porto')
      login_as(operator, scope: :user)
    end

    scenario 'sees the notes but cannot write them' do
      visit revenue_projection_history_path

      expect(page).to have_css('#history_days .history-note-row', text: 'Greve no porto')
      expect(page).to have_no_link('Anotar o dia 02/11/2026')

      page.driver.submit :patch, revenue_projection_day_note_path('2026-11-02'), { revenue_projection_day_note: { body: 'Outra' } }

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(RevenueProjection::DayNote.pluck(:body)).to eq(['Greve no porto'])
    end
  end

  context 'when the feature is turned off for the tenant' do
    let!(:owner) { create(:user, tenant: other_tenant, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not show the menu nor the screen' do
      visit root_path

      within('.sidebar-desktop') { expect(page).to have_no_link('Histórico da projeção') }

      visit revenue_projection_history_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when a user without access to the projection is signed in' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'cannot open the screen' do
      visit revenue_projection_history_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      build_history(tenant)
      login_as(owner, scope: :user)
    end

    scenario 'keeps the essential columns and does not scroll sideways' do
      visit revenue_projection_history_path
      use_mobile_screen

      expect(page).to have_css('.chart-card canvas')
      expect(page).to have_no_css('#history_days th', text: 'DIFERENÇA', visible: :visible)
      expect(page).to have_css('#history_days td', text: '+33,3%', visible: :visible)
      expect(page).to have_css('#history_weeks th', text: 'ABERTURA', visible: :visible)
      expect(page).to have_link('Anotar o dia 02/11/2026', visible: :visible)
      expect(page.evaluate_script("document.querySelector('#history_days').scrollWidth <= document.querySelector('#history_days').parentElement.clientWidth"))
        .to be(true)
      expect(page.evaluate_script("document.querySelector('#history_weeks').scrollWidth <= document.querySelector('#history_weeks').parentElement.clientWidth"))
        .to be(true)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
