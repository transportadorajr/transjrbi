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
        expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Mês atual')
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

      scenario 'switches to the history of the current week' do
        visit revenue_projection_history_path
        click_on 'Sem. atual'

        expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-07'))
        expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Sem. atual')
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

        click_on 'Mês atual'

        expect(page).to have_select('Mês', selected: 'Novembro de 2026')
      end

      scenario 'compares the daily forecasts with the billing of the range chosen in the filters' do
        visit revenue_projection_history_path

        within('#filtersModal') do
          fill_in 'Data inicial', with: '2026-11-02'
          fill_in 'Data final', with: '2026-11-03'
          click_on 'Aplicar Filtros'
        end

        expect(page).to have_current_path(%r{\A/revenue_projection_history\?start_date=2026-11-02&end_date=2026-11-03&plate=&})
        expect(page).to have_no_css('.dashboard-segmented .btn-primary')
        expect(page).to have_no_select('Mês')
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['Soma das previsões diárias até 03/11 R$ 1.300,00', 'Faturado no período R$ 1.600,00', 'Faturado x previsões diárias +R$ 300,00 (+23,1%)'],
        )
        expect(page).to have_text('Previsto x faturado no período')
        expect(html_table_to_rows(table: find_by_id('history_weeks'))).to eq(
          [['Semana', 'AberturaProjeção na abertura', 'Soma das previsões diárias', 'Faturado', 'Diferença', 'Situação'],
           ['02/11 a 03/11', 'R$ 1.300,00', 'R$ 1.300,00', 'R$ 1.600,00 +23,1%', '+R$ 300,00 (+23,1%)', 'Encerrada']],
        )
        expect(html_table_to_rows(table: find_by_id('history_days'))).to eq(
          [['Dia', 'Previsto', 'Faturado', 'Diferença', 'CT-es', 'Projeção do mês na manhã', 'Ações'],
           ['02/11 seg Feriado em dia útil', 'R$ 300,00', 'R$ 400,00 +33,3%', '+R$ 100,00 (+33,3%)', '2', 'R$ 23.100,00', ''],
           ['03/11 ter', 'R$ 1.000,00', 'R$ 1.200,00 +20,0%', '+R$ 200,00 (+20,0%)', '5', '-', '']],
        )
      end

      scenario 'does not accept an end date before the start date' do
        visit revenue_projection_history_path(start_date: '2026-11-03', end_date: '2026-11-02')

        expect(page).to have_current_path(revenue_projection_history_path)
        expect(page).to have_text('Data final não pode ser anterior à data inicial')
      end

      context 'with the forecast of today' do
        before do
          create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 4), forecast_cents: 100_000)
          create(:revenue_projection_snapshot, tenant:, period_type: 'week', period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 7),
                                               taken_on: Date.new(2026, 11, 4), projected_cents: 550_000)
          create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 4, 8), freight_cents: 70_000)
          create(:atua_import, tenant:, status_type: 'succeeded', finished_at: Time.zone.local(2026, 11, 4, 9, 30))
        end

        scenario 'compares the forecast of today with the billing so far' do
          visit revenue_projection_history_path
          click_on 'Hoje'

          expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-04', end_date: '2026-11-04'))
          expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Hoje')
          expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
            ['Previsão do dia R$ 1.000,00', 'Faturado hoje R$ 700,00', 'Projeção do mês hoje R$ 23.300,00', 'Projeção da semana hoje R$ 5.500,00'],
          )
          expect(page).to have_text('o faturado vai até a última sincronização com o Atua (04/11/2026 09:30)')
          expect(page).to have_no_table('history_days')
        end
      end
    end

    context 'with the documents of two trucks of two customer groups' do
      before do
        create(:atua_customer, tenant:, code: 7100, customer_group: create(:customer_group, tenant:, name: 'USIMINAS'))
        create(:atua_customer, tenant:, code: 7200, customer_group: create(:customer_group, tenant:, name: 'GERDAU'))
        (Date.new(2026, 8, 17)..Date.new(2026, 11, 3)).each do |date|
          next if date.sunday?

          issued_at = date.in_time_zone.change(hour: 10)
          create(:atua_transport_document, tenant:, plate: 'AAA1A11', taker_code: 7200, issued_at:, freight_cents: date.saturday? ? 50_000 : 100_000)
          create(:atua_transport_document, tenant:, plate: 'BBB2B22', taker_code: 7100, issued_at:, freight_cents: date.saturday? ? 25_000 : 50_000)
        end
        create(:atua_transport_document, tenant: other_tenant, plate: 'BBB2B22', issued_at: Time.zone.local(2026, 11, 3, 10), freight_cents: 9_900_000)
        RevenueProjections::RefreshMemoryCommand.call(tenant, at: Time.zone.local(2026, 11, 4, 6))
      end

      scenario 'recalculates the projection of each morning only with the documents of a truck' do
        visit revenue_projection_history_path

        expect(all('#history_cards .counter-card').map { it.text.squish }.first).to eq('Projeção na abertura (01/11) R$ 34.500,00')
        expect(page).to have_no_css('#history_cut')
        within('#filtersModal') do
          expect(page).to have_select('Macro região de origem')
          expect(page).to have_select('Tipo de conjunto')
          fill_in 'Placa', with: 'bbb2b22'
          click_on 'Aplicar Filtros'
        end

        expect(page).to have_current_path(/plate=bbb2b22/)
        expect(page).to have_css('#history_cut', text: 'Placa: BBB2B22')
        expect(page).to have_text('A projeção de cada manhã foi recalculada só com os CT-es deste recorte')
        expect(page).to have_no_text('foram reconstruídas a partir do histórico')
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['Projeção na abertura (01/11) R$ 11.500,00', 'Projeção atual (04/11) R$ 11.500,00', 'Faturado até 03/11 R$ 1.000,00',
           'Variação da projeção desde a abertura +R$ 0,00 (+0,0%)'],
        )
        expect(html_table_to_rows(table: find_by_id('history_days')).drop(1).map { it.values_at(0, 1, 2) }).to eq(
          [['01/11 dom', 'R$ 0,00', 'R$ 0,00'], ['02/11 seg', 'R$ 500,00', 'R$ 500,00 +0,0%'], ['03/11 ter', 'R$ 500,00', 'R$ 500,00 +0,0%']],
        )
        expect(RevenueProjection::Snapshot.where(tenant:).count).to eq(70)

        click_on 'Sem. atual'

        expect(page).to have_current_path(/plate=bbb2b22/)
        expect(all('#history_cards .counter-card').map { it.text.squish }.first).to eq('Projeção na abertura (01/11) R$ 2.750,00')
      end

      scenario 'chooses the customer group and the product in the filters on a phone', :js do
        parent = create(:product_group, tenant:, name: 'AÇO', activated_at: Time.current)
        create(:product_group, tenant:, name: 'BOBINA', parent:)
        use_mobile_screen(width: 360)
        visit revenue_projection_history_path
        find(:link, href: '#filtersModal').click

        within('#customer_group_id_select') do
          find('.select2-trigger').click
          find('.select2-option', text: 'USIMINAS').click
        end
        within('#product_group_id_select') do
          find('.select2-trigger').click
          find('.select2-option', text: 'AÇO').click
        end
        within('#product_id_select') do
          find('.select2-trigger').click
          expect(all('.select2-option').map(&:text)).to eq(['BOBINA (AÇO)'])
        end

        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end

      scenario 'writes a note on the projection of a truck and stays on the cut', :js do
        visit revenue_projection_history_path(plate: 'BBB2B22')
        find_by_id('history_days').find('tr', text: '02/11 seg').click_on('Anotar o dia 02/11/2026')

        within('#revenue_projection_day_note_modal') do
          fill_in 'Anotação', with: 'Caminhão parado na oficina'

          expect { click_on 'Salvar anotação' }.to change(RevenueProjection::DayNote, :count).by(1)
        end

        expect(page).to have_text('Anotação salva.')
        expect(page).to have_current_path(/plate=BBB2B22/)
        expect(page).to have_css('#history_cut', text: 'Placa: BBB2B22')
        expect(page).to have_css('#history_days .history-note-row', text: 'Caminhão parado na oficina')
        expect(RevenueProjection::DayNote.last).to have_attributes(tenant:, date: Date.new(2026, 11, 2), body: 'Caminhão parado na oficina')
      end

      scenario 'recalculates the projection of a customer group and of today' do
        visit revenue_projection_history_path(customer_group_id: CustomerGroup.find_by!(name: 'GERDAU').id)

        expect(page).to have_css('#history_cut', text: 'Grupo de clientes: GERDAU')
        expect(all('#history_cards .counter-card').map { it.text.squish }.first).to eq('Projeção na abertura (01/11) R$ 23.000,00')

        click_on 'Hoje'

        expect(page).to have_css('#history_cut', text: 'Grupo de clientes: GERDAU')
        expect(all('#history_cards .counter-card').map { it.text.squish }).to eq(
          ['Previsão do dia R$ 1.000,00', 'Faturado hoje R$ 0,00', 'Projeção do mês hoje R$ 23.000,00', 'Projeção da semana hoje R$ 5.500,00'],
        )
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
      expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-30'))
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
      visit revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-07')
      find_by_id('history_days').find('tr', text: '03/11 ter').click_on('Anotar o dia 03/11/2026')

      within('#revenue_projection_day_note_modal') do
        fill_in 'Anotação', with: 'Chuva na usina'

        expect { click_on 'Salvar anotação' }.to change(RevenueProjection::DayNote, :count).by(1)
      end

      expect(page).to have_text('Anotação salva.')
      expect(page).to have_current_path(revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-07'))
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
