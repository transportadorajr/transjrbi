require 'rails_helper'

RSpec.describe Dashboard::Trip do
  subject(:dashboard) { described_class.new(tenant.atua_manifests, dimension:, period: october) }

  let!(:tenant) { create(:tenant) }
  let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }
  let(:dimension) { 'driver' }

  def create_trip(code:, plate:, started_at:, distance_km:, documents:, status: 'Encerrado')
    create(:atua_manifest, tenant:, code:, plate:, status:, trip_started_at: started_at)
    documents.each do |number, freight_cents, driver_code, driver_name|
      create(:atua_transport_document, tenant:, number:, freight_cents:, plate:, driver_code:, driver_name:, issued_at: started_at)
      create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: number, calculated_distance_km: distance_km)
    end
  end

  def row_values(rows)
    rows.map do |row|
      [row.label, row.trips_count, row.loaded_km, row.gross.format, row.net.format, row.average&.format, row.net_average&.format,
       row.gross_per_km&.format, row.net_per_km&.format]
    end
  end

  context 'without trips in the period' do
    it 'is empty with a zeroed total' do
      expect(dashboard).to be_empty
      expect(row_values([dashboard.total])).to eq([['Total', 0, 0, 'R$ 0,00', 'R$ 0,00', nil, nil, nil, nil]])
    end
  end

  context 'with trips of two drivers and two vehicles' do
    let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 400,
                  documents: [['74001', 300_000, 10, 'JOSE SILVA'], ['74002', 100_000, 20, 'MARIA SOUZA']])
      create_trip(code: 41_002, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 20, 8), distance_km: 0,
                  documents: [['74003', 200_000, 20, 'MARIA SOUZA']])
      create_trip(code: 41_003, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 21, 8), distance_km: 250,
                  documents: [['74004', 500_000, 10, 'JOSE SILVA']])
      create_trip(code: 41_004, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 22, 8), distance_km: 900, status: 'Cancelado',
                  documents: [['74005', 900_000, 10, 'JOSE SILVA']])
      create_trip(code: 41_005, plate: 'AAA1A11', started_at: Time.zone.local(2026, 9, 15, 8), distance_km: 100,
                  documents: [['74006', 150_000, 10, 'JOSE SILVA']])
      create(:freight_expense, tenant:, transport_document: Atua::TransportDocument.find_by!(number: '74004'), amount_cents: 100_000)
      create(:atua_manifest, tenant: other_tenant, code: 41_006, plate: 'AAA1A11', trip_started_at: Time.zone.local(2026, 10, 3, 8))
    end

    it 'counts the trips of the period that were not canceled' do
      expect(Atua::Manifest.count).to eq(6)
      expect(dashboard).not_to be_empty
      expect(row_values([dashboard.total])).to eq([['Total', 3, 650, 'R$ 11.000,00', 'R$ 10.000,00', 'R$ 3.666,67', 'R$ 3.333,33', 'R$ 13,85', 'R$ 12,31']])
    end

    it 'credits each trip to the driver of its largest freight' do
      expect(row_values(dashboard.rows)).to eq(
        [
          ['JOSE SILVA', 2, 650, 'R$ 9.000,00', 'R$ 8.000,00', 'R$ 4.500,00', 'R$ 4.000,00', 'R$ 13,85', 'R$ 12,31'],
          ['MARIA SOUZA', 1, 0, 'R$ 2.000,00', 'R$ 2.000,00', 'R$ 2.000,00', 'R$ 2.000,00', nil, nil],
        ],
      )
    end

    context 'when the driver has a display name' do
      before { create(:driver, tenant:, code: 10, display_name: 'ZÉ') }

      it 'shows the display name' do
        expect(dashboard.rows.map(&:label)).to eq(['ZÉ', 'MARIA SOUZA'])
      end
    end

    context 'when grouped by vehicle' do
      let(:dimension) { 'vehicle' }

      it 'groups the trips by plate' do
        expect(row_values(dashboard.rows)).to eq(
          [
            ['AAA1A11', 2, 400, 'R$ 6.000,00', 'R$ 6.000,00', 'R$ 3.000,00', 'R$ 3.000,00', 'R$ 10,00', 'R$ 10,00'],
            ['BBB2B22', 1, 250, 'R$ 5.000,00', 'R$ 4.000,00', 'R$ 5.000,00', 'R$ 4.000,00', 'R$ 20,00', 'R$ 16,00'],
          ],
        )
      end

      it 'plots the gross and the net with the number of trips' do
        expect(dashboard.ranking_data).to eq(
          [
            { name: 'Frete bruto', data: { 'AAA1A11 (2)' => 6000.0, 'BBB2B22 (1)' => 5000.0 } },
            { name: 'Frete líquido', data: { 'AAA1A11 (2)' => 6000.0, 'BBB2B22 (1)' => 4000.0 } },
          ],
        )
        expect(dashboard.per_km_ranking_data).to eq(
          [
            { name: 'Frete bruto', data: { 'BBB2B22 (1)' => 20.0, 'AAA1A11 (2)' => 10.0 } },
            { name: 'Frete líquido', data: { 'BBB2B22 (1)' => 16.0, 'AAA1A11 (2)' => 10.0 } },
          ],
        )
      end

      it 'sorts the rows by the gross per km' do
        expect(dashboard.sorted_rows('gross_per_km', 'desc').map(&:label)).to eq(%w[BBB2B22 AAA1A11])
        expect(dashboard.sorted_rows('net', 'asc').map(&:label)).to eq(%w[BBB2B22 AAA1A11])
        expect(dashboard.sorted_rows('unknown', 'desc').map(&:label)).to eq(%w[AAA1A11 BBB2B22])
      end
    end

    it 'plots the gross and the net of the last six months by the start of the trip' do
      gross, net = dashboard.monthly_data

      expect(gross[:name]).to eq('Frete bruto')
      expect(gross[:data]).to eq(
        'Mai/2026 (0)' => 0.0, 'Jun/2026 (0)' => 0.0, 'Jul/2026 (0)' => 0.0, 'Ago/2026 (0)' => 0.0, 'Set/2026 (1)' => 1500.0, 'Out/2026 (3)' => 11_000.0,
      )
      expect(net[:name]).to eq('Frete líquido')
      expect(net[:data].values.last(2)).to eq([1500.0, 10_000.0])
      expect(dashboard.monthly_per_km_data.map { |serie| serie[:data].values }).to eq([[nil, nil, nil, nil, 15.0, 13.85], [nil, nil, nil, nil, 15.0, 12.31]])
    end

    it 'plots the gross and the net of the last twelve weeks from sunday to saturday' do
      gross, net = dashboard.weekly_data

      expect(gross[:data].size).to eq(12)
      expect(gross[:data].keys.values_at(0, -1)).to eq(['09/08 (0)', '25/10 (0)'])
      expect(gross[:data].select { |_, value| value.positive? }).to eq('13/09 (1)' => 1500.0, '27/09 (1)' => 4000.0, '18/10 (2)' => 7000.0)
      expect(net[:data].select { |_, value| value.positive? }).to eq('13/09 (1)' => 1500.0, '27/09 (1)' => 4000.0, '18/10 (2)' => 6000.0)
      expect(dashboard.weekly_per_km_data.map { |serie| serie[:data].compact }).to eq(
        [{ '13/09 (1)' => 15.0, '27/09 (1)' => 10.0, '18/10 (2)' => 20.0 }, { '13/09 (1)' => 15.0, '27/09 (1)' => 10.0, '18/10 (2)' => 16.0 }],
      )
    end
  end

  describe '.enabled?' do
    let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

    it 'is turned off by default' do
      expect(described_class.enabled?(tenant)).to be(false)
    end

    context 'when the trips dashboard is enabled for the tenant', flipper: { trips_dashboard: :tenant } do
      it 'is turned on only for that tenant' do
        expect(described_class.enabled?(tenant)).to be(true)
        expect(described_class.enabled?(other_tenant)).to be(false)
      end
    end
  end

  context 'with an unknown dimension' do
    let(:dimension) { 'customer_group' }

    it 'groups by driver' do
      expect(dashboard.dimension).to eq('driver')
    end
  end
end
