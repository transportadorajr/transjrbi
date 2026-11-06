require 'rails_helper'

describe 'Intelligence PDF exports' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }
  let(:october) { { start_date: '2026-10-01', end_date: '2026-10-31' } }

  before { login_as(owner, scope: :user) }

  def pdf_text
    PDF::Inspector::Text.analyze(page.body).strings.join
  end

  def landscape?
    width, height = PDF::Inspector::Page.analyze(page.body).pages.first[:size]
    width > height
  end

  context 'with access to the freight billing' do
    let!(:resource) { create(:resource, name: 'Faturamento', slug: 'freight_billing', writable: false) }

    context 'when there are trips in the period' do
      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:grouped_taker) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
      let!(:loose_taker) { create(:atua_customer, tenant:, code: 7200) }
      let!(:first_trip) { create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8)) }
      let!(:second_trip) { create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7)) }
      let!(:steel) do
        create(:atua_transport_document, tenant:, number: '74001', branch_code: 2, freight_cents: 1_000_000, weight_freight_cents: 900_000,
                                         toll_cents: 25_000, icms_cents: 75_000, plate: 'RVR2C34', driver_code: 10, driver_name: 'JOSE SILVA',
                                         taker_code: 7100, origin_city: 'IPATINGA', origin_state: 'MG')
      end
      let!(:steel_toll_voucher) { create(:atua_toll_voucher, tenant:, transport_document_number: '74001', branch_code: 2, toll_cents: 25_000) }
      let!(:coil) do
        create(:atua_transport_document, tenant:, number: '74002', freight_cents: 500_000, plate: 'RVR2C34', driver_code: 10, driver_name: 'JOSE SILVA',
                                         taker_code: 7200, origin_city: 'IPATINGA', origin_state: 'MG')
      end
      let!(:sheet) do
        create(:atua_transport_document, tenant:, number: '74003', freight_cents: 400_000, plate: 'RVR8J90', driver_code: 20,
                                         driver_name: 'MARIA SOUZA', taker_code: 7100, origin_city: 'BELO HORIZONTE', origin_state: 'MG')
      end
      let!(:complement) do
        create(:atua_transport_document, tenant:, number: '3547', document_kind: 'ce', freight_cents: 100_000, posted_on: Date.new(2026, 10, 15),
                                         plate: 'RVR8J90', driver_code: 20, driver_name: 'MARIA SOUZA', taker_code: 7100,
                                         origin_city: 'BELO HORIZONTE', origin_state: 'MG')
      end
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74001', freight_cents: 5_000_000, plate: 'OUT1A11') }

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
      end

      scenario 'shows the PDF export button with the applied filters' do
        visit freight_billing_path(**october, dimension: 'vehicle')

        expect(page).to have_link('Exportar PDF', href: freight_billing_path(**october, dimension: 'vehicle', format: :pdf))
      end

      scenario 'exports the indicators and every row of the grouping with its total on a landscape page' do
        travel_to Time.zone.local(2026, 11, 6, 14, 30) do
          visit freight_billing_path(**october, dimension: 'vehicle', format: :pdf)
        end

        expect(page.status_code).to eq(200)
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(landscape?).to be(true)
        expect(Atua::TransportDocument.count).to eq(5)

        text = pdf_text
        expect(text).to include('Relatório de Faturamento', 'Detalhamento por Veículo — CT-es emitidos de 01/10/2026 a 31/10/2026')
        expect(text).to include('Frete brutoR$ 20.000,00', 'Frete líquidoR$ 19.100,00', 'Viagens2', 'Frete bruto por kmR$ 26,39',
                                'Frete líquido por kmR$ 25,14', 'KM rodado720 km', 'KM vazio80 km', 'Rodou vazio11,1%')
        expect(text).to include('Veículo', 'Viagens', 'KM rodado', 'Frete bruto', 'Frete líquido', 'Pedágio', 'Bruto/km', 'Líquido/km', 'Participação')
        expect(text).to include('RVR2C34', 'R$ 15.000,00', 'R$ 14.100,00', 'R$ 250,00', '75,0%')
        expect(text).to include('RVR8J90', 'R$ 5.000,00', '25,0%')
        expect(text).to include('Total2', '100,0%')
        expect(text).to include('2 registros listados.', 'Gerado em 06/11/2026 14:30.')
        expect(text).not_to include('OUT1A11')
      end
    end

    context 'when there are no trips in the period' do
      scenario 'exports the zeroed indicators and tells that nothing was found' do
        visit freight_billing_path(**october, format: :pdf)

        expect(Atua::TransportDocument.count).to eq(0)
        expect(pdf_text).to include('Relatório de Faturamento', 'Frete brutoR$ 0,00', 'Nenhum registro encontrado', 'Nenhum registro listado.')
      end
    end
  end

  context 'with access to the trips', flipper: { trips_dashboard: :tenant } do
    let!(:resource) { create(:resource, name: 'Viagens', slug: 'trips', writable: false) }

    def create_trip(code:, plate:, started_at:, distance_km:, documents:, tenant: self.tenant)
      create(:atua_manifest, tenant:, code:, number: code.to_s, plate:, trip_started_at: started_at)
      documents.each do |number, freight_cents, driver_code, driver_name|
        create(:atua_transport_document, tenant:, number:, freight_cents:, plate:, driver_code:, driver_name:, issued_at: started_at)
        create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: number, calculated_distance_km: distance_km)
      end
    end

    context 'when there are trips of the tenant and of another tenant' do
      before do
        create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 400,
                    documents: [['74001', 300_000, 10, 'JOSE SILVA'], ['74002', 100_000, 20, 'MARIA SOUZA']])
        create_trip(code: 41_003, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 21, 8), distance_km: 250,
                    documents: [['74004', 500_000, 10, 'JOSE SILVA']])
        create_trip(tenant: other_tenant, code: 41_004, plate: 'CCC3C33', started_at: Time.zone.local(2026, 10, 5, 8), distance_km: 100,
                    documents: [['74005', 800_000, 30, 'PEDRO OUTRO']])
      end

      scenario 'shows the PDF export button with the applied filters' do
        visit trips_path(october)

        expect(page).to have_link('Exportar PDF', href: trips_path(**october, format: :pdf))
      end

      scenario 'exports the indicators and every row of the grouping with its total on a landscape page' do
        visit trips_path(**october, format: :pdf)

        expect(page.status_code).to eq(200)
        expect(landscape?).to be(true)
        expect(Atua::Manifest.count).to eq(3)

        text = pdf_text
        expect(text).to include('Relatório de Viagens', 'Motorista — Viagens iniciadas de 01/10/2026 a 31/10/2026')
        expect(text).to include('Viagens', 'Frete bruto', 'Frete líquido', 'Bruto/km', 'Líquido/km')
        expect(text).to include('JOSE SILVA', 'Viagens2', 'Frete brutoR$ 9.000,00', 'Total2', '1 registro listado.')
        expect(text).not_to include('PEDRO OUTRO')
      end
    end
  end
end
