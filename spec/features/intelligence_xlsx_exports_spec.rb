require 'rails_helper'

describe 'Intelligence Excel exports', :xlsx_service do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  before { login_as(owner, scope: :user) }

  context 'with access to the freight billing' do
    let!(:resource) { create(:resource, name: 'Faturamento', slug: 'freight_billing', writable: false) }

    context 'when there are trips in the period' do
      let!(:first_trip) { create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8)) }
      let!(:second_trip) { create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7)) }
      let!(:steel) do
        create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_500_000, plate: 'RVR2C34', driver_code: 10, driver_name: 'JOSE SILVA',
                                         origin_city: 'IPATINGA', origin_state: 'MG')
      end
      let!(:sheet) do
        create(:atua_transport_document, tenant:, number: '74003', freight_cents: 500_000, plate: 'RVR8J90', driver_code: 20,
                                         driver_name: 'MARIA SOUZA', origin_city: 'BELO HORIZONTE', origin_state: 'MG')
      end
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74001', freight_cents: 5_000_000, plate: 'OUT1A11') }

      before do
        create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001', calculated_distance_km: 500)
        create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74003', calculated_distance_km: 200)
        create(:freight_expense, tenant:, transport_document: steel, amount_cents: 90_000)
      end

      scenario 'shows the Excel export button with the applied filters' do
        visit freight_billing_path(**october, dimension: 'vehicle')

        expect(page).to have_link('Exportar Excel', href: freight_billing_path(**october, dimension: 'vehicle', format: :xlsx))
      end

      scenario 'exports every indicator of each row of the grouping and the total' do
        visit freight_billing_path(**october, dimension: 'vehicle', sort: 'gross', direction: 'desc')
        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include('attachment', "filename=\"faturamento-#{Date.current.iso8601}.xlsx\"")
        expect(Atua::TransportDocument.count).to eq(3)
        expect(downloaded_xlsx_sheet_names).to eq(['Detalhamento por Veículo'])
        expect(downloaded_xlsx_rows.first).to eq(
          ['Veículo', 'Viagens', 'KM rodado', 'KM vazio', 'Rodou vazio', 'Situação do KM vazio', 'Frete bruto', 'Despesas de frete', 'Despesas', 'Pedágio pago pela JR',
           'Pedágio pago ou recobrado do cliente', 'Frete líquido', 'Bruto/km', 'Líquido/km', 'Participação'],
        )
        expect(downloaded_xlsx_records.map { |record| record.slice('Veículo', 'Viagens', 'KM rodado', 'Frete bruto', 'Frete líquido', 'Bruto/km', 'Participação') })
          .to eq(
            [{ 'Veículo' => 'RVR2C34', 'Viagens' => 1, 'KM rodado' => 500, 'Frete bruto' => 15_000, 'Frete líquido' => 14_100, 'Bruto/km' => 30,
               'Participação' => 0.75 },
             { 'Veículo' => 'RVR8J90', 'Viagens' => 1, 'KM rodado' => 200, 'Frete bruto' => 5_000, 'Frete líquido' => 5_000, 'Bruto/km' => 25,
               'Participação' => 0.25 },
             { 'Veículo' => 'Total', 'Viagens' => 2, 'KM rodado' => 700, 'Frete bruto' => 20_000, 'Frete líquido' => 19_100,
               'Bruto/km' => 28.57, 'Participação' => 1 }],
          )
      end
    end

    context 'when the month comparison is turned on', flipper: { freight_month_comparison: :tenant } do
      before do
        create(:atua_customer, tenant:, code: 7101, customer_group: create(:customer_group, tenant:, name: 'ARCELOR'))
        create(:atua_transport_document, tenant:, taker_code: 7101, freight_cents: 1_500_000, issued_at: Time.zone.local(2026, 10, 2, 10))
        create(:atua_transport_document, tenant:, taker_code: 7101, freight_cents: 1_000_000, issued_at: Time.zone.local(2026, 9, 2, 10))
      end

      scenario 'exports the previous gross and the variation of each customer group' do
        visit freight_billing_path(**october, format: :xlsx)

        expect(Atua::TransportDocument.count).to eq(2)
        expect(downloaded_xlsx_rows.first.last(2)).to eq(['Bruto mês passado', 'Variação'])
        expect(downloaded_xlsx_records.map { |record| record.slice('Grupo de clientes', 'Frete bruto', 'Bruto mês passado', 'Variação') }).to eq(
          [{ 'Grupo de clientes' => 'ARCELOR', 'Frete bruto' => 15_000, 'Bruto mês passado' => 10_000, 'Variação' => 0.5 },
           { 'Grupo de clientes' => 'Total', 'Frete bruto' => 15_000, 'Bruto mês passado' => 10_000, 'Variação' => 0.5 }],
        )
      end

      context 'with freight in the previous week' do
        before do
          create(:atua_transport_document, tenant:, taker_code: 7101, freight_cents: 500_000, issued_at: Time.zone.local(2026, 9, 22, 10))
        end

        scenario 'names the previous gross after the week' do
          visit freight_billing_path(start_date: '2026-09-27', end_date: '2026-10-03', format: :xlsx)

          expect(Atua::TransportDocument.count).to eq(3)
          expect(downloaded_xlsx_rows.first.last(2)).to eq(['Bruto semana passada', 'Variação'])
          expect(downloaded_xlsx_records.map { |record| record.slice('Grupo de clientes', 'Frete bruto', 'Bruto semana passada') }).to eq(
            [{ 'Grupo de clientes' => 'ARCELOR', 'Frete bruto' => 15_000, 'Bruto semana passada' => 5_000 },
             { 'Grupo de clientes' => 'Total', 'Frete bruto' => 15_000, 'Bruto semana passada' => 5_000 }],
          )
        end
      end
    end

    context 'when there are no trips in the period' do
      scenario 'exports only the header row' do
        visit freight_billing_path(**october, format: :xlsx)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(downloaded_xlsx_rows.size).to eq(1)
      end
    end
  end

  context 'with access to the trips', flipper: { trips_dashboard: :tenant } do
    let!(:resource) { create(:resource, name: 'Viagens', slug: 'trips', writable: false) }

    before do
      [[41_001, 'AAA1A11', 400, '74001', 300_000, 10, 'JOSE SILVA'], [41_003, 'BBB2B22', 250, '74004', 500_000, 10, 'JOSE SILVA'],
       [41_002, 'DDD4D44', 100, '74002', 100_000, 20, 'MARIA SOUZA']].each do |code, plate, distance_km, number, freight_cents, driver_code, driver_name|
        started_at = Time.zone.local(2026, 10, 2 + (code % 10), 8)
        create(:atua_manifest, tenant:, code:, number: code.to_s, plate:, trip_started_at: started_at, closed_at: started_at + 30.hours)
        create(:atua_transport_document, tenant:, number:, freight_cents:, plate:, driver_code:, driver_name:, issued_at: started_at)
        create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: number, calculated_distance_km: distance_km)
      end
      create(:atua_manifest, tenant: other_tenant, code: 41_004, plate: 'CCC3C33', trip_started_at: Time.zone.local(2026, 10, 5, 8))
    end

    scenario 'exports every indicator of each driver and the total' do
      visit trips_path(october)
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', "filename=\"viagens-#{Date.current.iso8601}.xlsx\"")
      expect(Atua::Manifest.count).to eq(4)
      expect(downloaded_xlsx_rows.first).to eq(
        ['Motorista', 'Viagens', 'KM rodado', 'Frete bruto', 'Despesas', 'Frete líquido', 'Média bruta por viagem', 'Média líquida por viagem',
         'Bruto/km', 'Líquido/km', 'Tempo médio (horas)'],
      )
      expect(downloaded_xlsx_records.map { |record| record.slice('Motorista', 'Viagens', 'KM rodado', 'Frete bruto', 'Bruto/km', 'Tempo médio (horas)') }).to eq(
        [{ 'Motorista' => 'JOSE SILVA', 'Viagens' => 2, 'KM rodado' => 650, 'Frete bruto' => 8_000, 'Bruto/km' => 12.31, 'Tempo médio (horas)' => 30 },
         { 'Motorista' => 'MARIA SOUZA', 'Viagens' => 1, 'KM rodado' => 100, 'Frete bruto' => 1_000, 'Bruto/km' => 10, 'Tempo médio (horas)' => 30 },
         { 'Motorista' => 'Total', 'Viagens' => 3, 'KM rodado' => 750, 'Frete bruto' => 9_000, 'Bruto/km' => 12, 'Tempo médio (horas)' => 30 }],
      )
    end
  end

  context 'with access to the export summary', flipper: { export_summary: :tenant } do
    let!(:resource) { create(:resource, name: 'Resumo da exportação', slug: 'export_summary', writable: false) }

    before do
      arcelor = create(:customer_group, tenant:, name: 'ARCELORMITTAL', in_export_summary_at: Time.current)
      create(:atua_customer, tenant:, code: 100, customer_group: arcelor)
      create(:atua_customer, tenant:, code: 300, name: 'ACEROS ASUNCION SA', state: 'EX', country_type: 'paraguay')
      create(:atua_manifest, tenant:, code: 41_001, number: '41001', plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
      create(:atua_transport_document, tenant:, number: '74001', cargo_destination_type: 'export', taker_code: 100, recipient_code: 300,
                                       recipient_name: 'ACEROS ASUNCION SA', origin_city: 'JUIZ DE FORA', origin_state: 'MG', weight_tons: BigDecimal('30.5'))
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001')
    end

    scenario 'exports the tons of each plant and country and every document of the total' do
      visit export_summary_path(october)
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', "filename=\"resumo-da-exportacao-#{Date.current.iso8601}.xlsx\"")
      expect(downloaded_xlsx_records).to eq(
        [{ 'Cliente' => 'ARCELORMITTAL', 'Planta de origem' => 'JUIZ DE FORA/MG', 'País de destino' => 'Paraguai', 'Toneladas' => 30.5,
           'Carregamentos' => 1, 'CT-es' => 1, '% do total' => 1 },
         { 'Cliente' => 'Total', 'Planta de origem' => 'Total', 'País de destino' => 'Total', 'Toneladas' => 30.5, 'Carregamentos' => 1,
           'CT-es' => 1, '% do total' => 1 }],
      )
      expect(downloaded_xlsx_records(1).map { |record| record.slice('CT-e', 'MDF-e', 'Cliente', 'País de destino', 'Toneladas') }).to eq(
        [{ 'CT-e' => '74001', 'MDF-e' => '41001', 'Cliente' => 'ARCELORMITTAL', 'País de destino' => 'Paraguai', 'Toneladas' => 30.5 }],
      )
    end
  end

  context 'with the documents of two trucks in the revenue projection history' do
    let!(:resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }

    before do
      travel_to(Time.zone.local(2026, 11, 4, 10))
      create(:atua_customer, tenant:, code: 7100, customer_group: create(:customer_group, tenant:, name: 'USIMINAS'))
      (Date.new(2026, 8, 17)..Date.new(2026, 11, 3)).each do |date|
        next if date.sunday?

        issued_at = date.in_time_zone.change(hour: 10)
        create(:atua_transport_document, tenant:, plate: 'AAA1A11', issued_at:, freight_cents: date.saturday? ? 50_000 : 100_000)
        create(:atua_transport_document, tenant:, plate: 'BBB2B22', taker_code: 7100, issued_at:, freight_cents: date.saturday? ? 25_000 : 50_000)
      end
      RevenueProjections::RefreshMemoryCommand.call(tenant, at: Time.zone.local(2026, 11, 4, 6))
    end

    scenario 'exports the projection recalculated for a cut and tells which cut it is' do
      visit revenue_projection_history_path(plate: 'BBB2B22', customer_group_id: CustomerGroup.find_by!(name: 'USIMINAS').id)
      click_on 'Exportar Excel'

      expect(downloaded_xlsx_records('Resumo').map { it.slice('Período', 'Recorte', 'Projeção na abertura', 'Faturado') }).to eq(
        [{ 'Período' => 'Novembro de 2026', 'Recorte' => 'Placa: BBB2B22, Grupo de clientes: USIMINAS', 'Projeção na abertura' => 11_500, 'Faturado' => 1_000 }],
      )
      expect(downloaded_xlsx_records('Evolução da projeção').map { it.slice('Data', 'Projeção do mês', 'Reconstruída') }).to eq(
        [{ 'Data' => Date.new(2026, 11, 1), 'Projeção do mês' => 11_500, 'Reconstruída' => 'Sim' },
         { 'Data' => Date.new(2026, 11, 2), 'Projeção do mês' => 11_500, 'Reconstruída' => 'Sim' },
         { 'Data' => Date.new(2026, 11, 3), 'Projeção do mês' => 11_500, 'Reconstruída' => 'Sim' },
         { 'Data' => Date.new(2026, 11, 4), 'Projeção do mês' => 11_500, 'Reconstruída' => 'Sim' }],
      )
      expect(downloaded_xlsx_records('Dia a dia').map { it.slice('Dia', 'Previsto', 'Faturado') }.last).to eq(
        'Dia' => Date.new(2026, 11, 3), 'Previsto' => 500, 'Faturado' => 500,
      )
      expect(downloaded_xlsx_records('Projeção por veículo').map { it.slice('Veículo', 'Faturado', 'Projeção', 'A faturar', 'Participação') }).to eq(
        [{ 'Veículo' => 'BBB2B22', 'Faturado' => 1_000, 'Projeção' => 11_500, 'A faturar' => 10_500, 'Participação' => 1 },
         { 'Veículo' => 'Total', 'Faturado' => 1_000, 'Projeção' => 11_500, 'A faturar' => 10_500, 'Participação' => 1 }],
      )
    end

    scenario 'exports the forecast of today of a cut' do
      visit revenue_projection_history_path(start_date: '2026-11-04', end_date: '2026-11-04', plate: 'AAA1A11')
      click_on 'Exportar Excel'

      expect(downloaded_xlsx_records('Resumo').map { it.slice('Dia', 'Recorte', 'Previsão do dia', 'Projeção do mês hoje') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 4), 'Recorte' => 'Placa: AAA1A11', 'Previsão do dia' => 1_000, 'Projeção do mês hoje' => 23_000 }],
      )
    end
  end

  context 'with access to the revenue projection history' do
    let!(:resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }

    before do
      travel_to(Time.zone.local(2026, 11, 4, 10))
      [[Date.new(2026, 11, 1), 2_300_000, true], [Date.new(2026, 11, 4), 2_330_000, false]].each do |taken_on, projected_cents, reconstructed|
        create(:revenue_projection_snapshot, tenant:, taken_on:, reference_at: taken_on.in_time_zone.change(hour: 5), realized_cents: 0, projected_cents:,
                                             low_cents: projected_cents, high_cents: projected_cents, reconstructed:)
      end
      create(:revenue_projection_snapshot, tenant:, period_type: 'week', period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 7),
                                           taken_on: Date.new(2026, 11, 1), days: [{ date: '2026-11-02', realized_cents: 0, expected_cents: 30_000 }])
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 11, 2), billed_cents: 40_000, documents_count: 2, day_type: 'weekday_holiday')
      create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 2), forecast_cents: 30_000, day_type: 'weekday_holiday')
      create(:revenue_projection_day_note, tenant:, user: owner, date: Date.new(2026, 11, 2), body: 'Greve no porto')
    end

    scenario 'exports the summary, the evolution of the projection, the weeks and the days of the month' do
      visit revenue_projection_history_path
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', 'filename="historico-da-projecao-2026-11-04.xlsx"')
      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Evolução da projeção', 'Semana a semana', 'Dia a dia'])
      expect(downloaded_xlsx_records('Resumo')).to match(
        [{ 'Período' => 'Novembro de 2026', 'Recorte' => 'Empresa inteira', 'Data da abertura' => Date.new(2026, 11, 1), 'Projeção na abertura' => 23_000,
           'Data da última projeção' => Date.new(2026, 11, 4), 'Última projeção' => 23_300, 'Faturado até' => Date.new(2026, 11, 3),
           'Faturado' => 400, 'Diferença' => 300, 'Diferença (%)' => be_within(0.0001).of(0.013), 'Período encerrado' => 'Não',
           'Projeção a menos de 5% desde' => nil }],
      )
      expect(downloaded_xlsx_records('Evolução da projeção')).to eq(
        [{ 'Data' => Date.new(2026, 11, 1), 'Dados do Atua até' => DateTime.new(2026, 11, 1, 5), 'Faturado acumulado' => 0, 'Projeção do mês' => 23_000,
           'Mínimo provável' => 23_000, 'Máximo provável' => 23_000, 'Reconstruída' => 'Sim' },
         { 'Data' => Date.new(2026, 11, 4), 'Dados do Atua até' => DateTime.new(2026, 11, 4, 5), 'Faturado acumulado' => 0, 'Projeção do mês' => 23_300,
           'Mínimo provável' => 23_300, 'Máximo provável' => 23_300, 'Reconstruída' => 'Não' }],
      )
      expect(downloaded_xlsx_records('Semana a semana')).to eq(
        [{ 'Início' => Date.new(2026, 11, 1), 'Fim' => Date.new(2026, 11, 7), 'Projeção na abertura' => 300, 'Soma das previsões diárias' => 300,
           'Faturado' => 400, 'Diferença' => nil, 'Diferença (%)' => nil, 'Situação' => 'Em andamento' }],
      )
      expect(downloaded_xlsx_records('Dia a dia').map { it.slice('Dia', 'Tipo do dia', 'Previsto', 'Faturado', 'Diferença', 'CT-es', 'Anotação', 'Autor da anotação') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 1), 'Tipo do dia' => 'Dia normal', 'Previsto' => nil, 'Faturado' => 0, 'Diferença' => nil, 'CT-es' => 0,
           'Anotação' => nil, 'Autor da anotação' => nil },
         { 'Dia' => Date.new(2026, 11, 2), 'Tipo do dia' => 'Feriado em dia útil', 'Previsto' => 300, 'Faturado' => 400, 'Diferença' => 100, 'CT-es' => 2,
           'Anotação' => 'Greve no porto', 'Autor da anotação' => 'Bruna Dona' },
         { 'Dia' => Date.new(2026, 11, 3), 'Tipo do dia' => 'Dia normal', 'Previsto' => nil, 'Faturado' => 0, 'Diferença' => nil, 'CT-es' => 0,
           'Anotação' => nil, 'Autor da anotação' => nil }],
      )
    end

    scenario 'exports the history of the week without the sheet of the weeks' do
      visit revenue_projection_history_path(start_date: '2026-11-01', end_date: '2026-11-07')
      click_on 'Exportar Excel'

      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Evolução da projeção', 'Dia a dia'])
      expect(downloaded_xlsx_records('Resumo').map { it.slice('Período', 'Projeção na abertura', 'Faturado', 'Período encerrado') }).to eq(
        [{ 'Período' => '01/11 a 07/11/2026', 'Projeção na abertura' => 23_000, 'Faturado' => 400, 'Período encerrado' => 'Não' }],
      )
      expect(downloaded_xlsx_records('Evolução da projeção').map { it.slice('Data', 'Projeção da semana') }).to eq(
        [{ 'Data' => Date.new(2026, 11, 1), 'Projeção da semana' => 23_000 }],
      )
      expect(downloaded_xlsx_records('Dia a dia').map { it.slice('Dia', 'Projeção da semana na manhã') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 1), 'Projeção da semana na manhã' => 23_000 }, { 'Dia' => Date.new(2026, 11, 2), 'Projeção da semana na manhã' => nil },
         { 'Dia' => Date.new(2026, 11, 3), 'Projeção da semana na manhã' => nil }],
      )
    end

    scenario 'exports the forecast of today with the billing so far' do
      create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 4), forecast_cents: 100_000)
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 4, 8), freight_cents: 70_000)

      visit revenue_projection_history_path(start_date: '2026-11-04', end_date: '2026-11-04')
      click_on 'Exportar Excel'

      expect(downloaded_xlsx_sheet_names).to eq(['Resumo'])
      expect(downloaded_xlsx_records('Resumo').map { it.slice('Dia', 'Previsão do dia', 'Faturado hoje', 'Diferença', 'CT-es', 'Projeção do mês hoje') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 4), 'Previsão do dia' => 1_000, 'Faturado hoje' => 700, 'Diferença' => -300, 'CT-es' => 1,
           'Projeção do mês hoje' => 23_300 }],
      )
    end

    scenario 'exports the daily forecasts and the billing of a range of days' do
      visit revenue_projection_history_path(start_date: '2026-11-02', end_date: '2026-11-03')
      click_on 'Exportar Excel'

      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Semana a semana', 'Dia a dia'])
      expect(downloaded_xlsx_records('Resumo')).to match(
        [{ 'Período' => '02/11/2026 a 03/11/2026', 'Recorte' => 'Empresa inteira', 'Faturado até' => Date.new(2026, 11, 3), 'Soma das previsões diárias' => 300, 'Faturado' => 400,
           'Diferença' => 100, 'Diferença (%)' => be_within(0.0001).of(0.3333), 'Período encerrado' => 'Sim' }],
      )
      expect(downloaded_xlsx_records('Dia a dia').map { it.slice('Dia', 'Projeção do mês na manhã') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 2), 'Projeção do mês na manhã' => nil }, { 'Dia' => Date.new(2026, 11, 3), 'Projeção do mês na manhã' => nil }],
      )
    end
  end

  context 'with access to the goals panel' do
    let!(:resource) { create(:resource, name: 'Painel de metas', slug: 'goals', writable: false) }
    let(:month) { Date.new(2026, 11, 1) }

    before do
      travel_to(Time.zone.local(2026, 11, 10, 10))
      create(:own_fleet, tenant:, plates: %w[AJR4391 RHJ5A50])
      %w[AJR4391 RHJ5A50].each { |plate| create(:atua_vehicle, tenant:, plate:) }
      usiminas = create(:customer_group, tenant:, name: 'USIMINAS')
      create(:revenue_goal, tenant:, month:, amount_cents: 10_000_000)
      create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391', amount_cents: 1_000_000)
      create(:revenue_goal, :customer_group, tenant:, month:, customer_group: usiminas, amount_cents: 6_000_000)
      create(:atua_transport_document, tenant:, plate: 'AJR4391', freight_cents: 900_000, issued_at: Time.zone.local(2026, 11, 5, 10),
                                       taker_code: create(:atua_customer, tenant:, customer_group: usiminas).code)
      create(:atua_transport_document, tenant:, plate: 'XYZ9K87', freight_cents: 250_000, issued_at: Time.zone.local(2026, 11, 5, 10))
      create(:atua_transport_document, tenant: other_tenant, plate: 'AJR4391', freight_cents: 7_000_000, issued_at: Time.zone.local(2026, 11, 5, 10))
    end

    scenario 'shows the Excel export button with the chosen grouping' do
      visit goals_path(dimension: 'vehicle', page: 2)

      expect(page).to have_link('Exportar Excel', href: goals_path(dimension: 'vehicle', format: :xlsx))
    end

    scenario 'exports the summary of the company and every row of the chosen grouping' do
      visit goals_path(dimension: 'vehicle')
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include("filename=\"metas-#{Date.current.iso8601}.xlsx\"")
      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Ranking dos veículos'])
      expect(downloaded_xlsx_records('Resumo')).to eq(
        [{ 'Mês' => 'Novembro de 2026', 'Meta' => 100_000, 'Faturado' => 11_500, 'Falta' => 88_500, 'Atingimento' => 0.115,
           'Projeção de fechamento' => 35_937.5, 'Ritmo necessário por dia útil' => 5_205.89, 'Situação' => 'Abaixo da meta',
           'Meta da semana' => 24_000, 'Faturado na semana' => 0, 'Atingimento na semana' => 0 }],
      )
      expect(downloaded_xlsx_records('Ranking dos veículos')).to eq(
        [{ 'Placa' => 'AJR4391', 'Meta' => 10_000, 'Faturado' => 9_000, 'Falta' => 1_000, 'Atingimento' => 0.9, 'Projeção' => 28_125,
           'Situação' => 'No ritmo' },
         { 'Placa' => 'RHJ5A50', 'Meta' => nil, 'Faturado' => 0, 'Falta' => nil, 'Atingimento' => nil, 'Projeção' => 0, 'Situação' => 'Sem meta' },
         { 'Placa' => 'Terceiro', 'Meta' => nil, 'Faturado' => 2_500, 'Falta' => nil, 'Atingimento' => nil, 'Projeção' => 7_812.5,
           'Situação' => 'Sem meta' }],
      )
    end

    scenario 'exports the customer groups with the columns of the week' do
      visit goals_path(format: :xlsx)

      expect(downloaded_xlsx_records('Metas por grupo de clientes').map { it.slice('Grupo de clientes', 'Meta', 'Faturado', 'Meta da semana') }).to eq(
        [{ 'Grupo de clientes' => 'USIMINAS', 'Meta' => 60_000, 'Faturado' => 9_000, 'Meta da semana' => 14_400 },
         { 'Grupo de clientes' => 'Sem grupo de clientes', 'Meta' => nil, 'Faturado' => 2_500, 'Meta da semana' => nil }],
      )
    end
  end
end
