require 'rails_helper'

describe 'Intelligence Excel exports', :xlsx_service, flipper: { xlsx_export: :tenant } do
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
          ['Veículo', 'Viagens', 'KM rodado', 'KM vazio', 'Rodou vazio', 'Frete bruto', 'Despesas de frete', 'Despesas', 'Pedágio pago pela JR',
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

    context 'when there are no trips in the period' do
      scenario 'exports only the header row' do
        visit freight_billing_path(**october, format: :xlsx)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(downloaded_xlsx_rows.size).to eq(1)
      end
    end
  end

  context 'with access to the trips', flipper: { trips_dashboard: :tenant, xlsx_export: :tenant } do
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

  context 'with access to the revenue projection', flipper: { revenue_projection: :tenant, xlsx_export: :tenant } do
    let!(:resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }
    let(:now) { Time.zone.local(2026, 11, 11, 15) }

    before do
      travel_to(now)
      (Date.new(2026, 8, 17)..Date.new(2026, 11, 11)).each do |date|
        next if date.sunday?

        create(:atua_transport_document, tenant:, issued_at: date.in_time_zone.change(hour: 10), freight_cents: date.saturday? ? 50_000 : 100_000)
      end
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: now)
      RevenueProjections::RefreshMemoryCommand.call(tenant, at: now.change(hour: 6))
    end

    scenario 'exports the projection, the day by day billing and the memory of the projection' do
      visit revenue_projection_path
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', 'filename="projecao-de-faturamento-2026-11-11.xlsx"')
      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Dia a dia', 'Onde a projeção erra', 'O que a projeção aprendeu'])
      expect(downloaded_xlsx_records('Resumo')).to eq(
        [{ 'Período' => 'Mês de novembro de 2026', 'Faturado até' => DateTime.new(2026, 11, 11, 15), 'Faturado' => 8_500, 'Projeção' => 23_000,
           'Mínimo provável' => 23_000, 'Máximo provável' => 23_000 }],
      )
      expect(downloaded_xlsx_records('Dia a dia').size).to eq(30)
      expect(downloaded_xlsx_records('Dia a dia').first).to eq(
        'Data' => Date.new(2026, 11, 1), 'Faturado' => 0, 'Previsto' => 0, 'Mínimo provável' => 0, 'Máximo provável' => 0, 'Feriado' => nil,
      )
      expect(downloaded_xlsx_rows('Onde a projeção erra').first).to eq(['Dia', 'Dias', 'Erro médio', 'Tendência'])
      expect(downloaded_xlsx_records('O que a projeção aprendeu')).to include(
        'Ajuste' => 'Fim de mês', 'Valor' => 1, 'Base (dias)' => 6, 'Situação' => 'Aprendido',
      )
    end
  end

  context 'with access to the revenue projection history', flipper: { revenue_projection: :tenant, xlsx_export: :tenant } do
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
    end

    scenario 'exports the summary, the evolution of the projection, the weeks and the days of the month' do
      visit revenue_projection_history_path
      click_on 'Exportar Excel'

      expect(page.response_headers['Content-Disposition']).to include('attachment', 'filename="historico-da-projecao-2026-11-04.xlsx"')
      expect(downloaded_xlsx_sheet_names).to eq(['Resumo', 'Evolução da projeção', 'Semana a semana', 'Dia a dia'])
      expect(downloaded_xlsx_records('Resumo')).to match(
        [{ 'Mês' => 'Novembro de 2026', 'Data da abertura' => Date.new(2026, 11, 1), 'Projeção na abertura' => 23_000,
           'Data da última projeção' => Date.new(2026, 11, 4), 'Última projeção' => 23_300, 'Faturado até' => Date.new(2026, 11, 3),
           'Faturado' => 400, 'Diferença' => 300, 'Diferença (%)' => be_within(0.0001).of(0.013), 'Mês encerrado' => 'Não',
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
      expect(downloaded_xlsx_records('Dia a dia').map { it.slice('Dia', 'Tipo do dia', 'Previsto', 'Faturado', 'Diferença', 'CT-es') }).to eq(
        [{ 'Dia' => Date.new(2026, 11, 1), 'Tipo do dia' => 'Dia normal', 'Previsto' => nil, 'Faturado' => 0, 'Diferença' => nil, 'CT-es' => 0 },
         { 'Dia' => Date.new(2026, 11, 2), 'Tipo do dia' => 'Feriado em dia útil', 'Previsto' => 300, 'Faturado' => 400, 'Diferença' => 100, 'CT-es' => 2 },
         { 'Dia' => Date.new(2026, 11, 3), 'Tipo do dia' => 'Dia normal', 'Previsto' => nil, 'Faturado' => 0, 'Diferença' => nil, 'CT-es' => 0 }],
      )
    end
  end
end
