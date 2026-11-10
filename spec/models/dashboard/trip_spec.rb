require 'rails_helper'

RSpec.describe Dashboard::Trip do
  subject(:dashboard) { described_class.new(tenant.atua_manifests, dimension:, period: october) }

  let!(:tenant) { create(:tenant) }
  let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }
  let(:dimension) { 'driver' }

  def create_trip(code:, plate:, started_at:, distance_km:, documents:, status: 'Encerrado')
    create(:atua_manifest, tenant:, code:, number: code.to_s, plate:, status:, trip_started_at: started_at)
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

  context 'with closed trips and a trip in progress' do
    let(:dimension) { 'vehicle' }

    before do
      create_trip(code: 41_001, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 2, 8), distance_km: 400,
                  documents: [['74001', 300_000, 10, 'JOSE SILVA']])
      create_trip(code: 41_002, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 10, 8), distance_km: 300,
                  documents: [['74002', 400_000, 10, 'JOSE SILVA']])
      create_trip(code: 41_003, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 12, 8), distance_km: 300,
                  documents: [['74003', 900_000, 20, 'MARIA SOUZA']], status: 'Normal')
      Atua::Manifest.find_by!(code: 41_001).update!(closed_at: Time.zone.local(2026, 10, 3, 10))
      Atua::Manifest.find_by!(code: 41_002).update!(closed_at: Time.zone.local(2026, 10, 10, 20))
    end

    def duration_values(rows)
      rows.map { |row| [row.label, row.duration&.hours, row.net_per_hour&.format] }
    end

    it 'averages the duration and the net freight per hour leaving the trip in progress out' do
      expect(duration_values(dashboard.rows + [dashboard.total])).to eq(
        [['BBB2B22', nil, nil], ['AAA1A11', 19, 'R$ 184,21'], ['Total', 19, 'R$ 184,21']],
      )
    end

    it 'sorts the vehicles from the fastest leaving the vehicles without a duration last' do
      expect(dashboard.sorted_rows('duration', 'asc').map(&:label)).to eq(%w[AAA1A11 BBB2B22])
      expect(dashboard.sorted_rows('net_per_hour', 'desc').map(&:label)).to eq(%w[AAA1A11 BBB2B22])
    end

    it 'finds a row and the total by key and nothing for an unknown key' do
      expect(dashboard.find_row('AAA1A11').trips_count).to eq(2)
      expect(dashboard.find_row('total')).to eq(dashboard.total)
      expect(dashboard.find_row('ZZZ9Z99')).to be_nil
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

    it 'exposes the gross, net and km the per km is calculated on and what is left out of it' do
      expect(dashboard.per_km_base).to have_attributes(gross: Money.from_cents(900_000), net: Money.from_cents(800_000), loaded_km: BigDecimal('650'),
                                                       excluded_count: 1, excluded_gross: Money.from_cents(200_000),
                                                       excluded_net: Money.from_cents(200_000))
      expect(dashboard.per_km_base).to be_excluded
      expect((dashboard.per_km_base.gross.cents / dashboard.per_km_base.loaded_km).round).to eq(dashboard.total.gross_per_km.cents)
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
      end

      it 'sorts the rows by the net per km from the best when no known column is given' do
        expect(dashboard.sorted_rows('unknown', 'asc').map(&:label)).to eq(%w[BBB2B22 AAA1A11])
        expect(dashboard.sorted_rows(nil, nil).map(&:label)).to eq(%w[BBB2B22 AAA1A11])
      end

      it 'subtracts the net from the gross as the expenses' do
        expect(dashboard.rows.map { |row| [row.label, row.expenses.format] }).to eq([['AAA1A11', 'R$ 0,00'], ['BBB2B22', 'R$ 1.000,00']])
        expect(dashboard.total.expenses.format).to eq('R$ 1.000,00')
      end

      it 'highlights the best and the worst by the net per km unless sorted by the gross per km' do
        expect(dashboard.highlights(nil)).to eq('BBB2B22' => :best, 'AAA1A11' => :worst)
        expect(dashboard.highlights('gross_per_km')).to eq('BBB2B22' => :best, 'AAA1A11' => :worst)
      end
    end

    context 'when grouped by an unavailable manifest dimension' do
      let(:dimension) { 'manifest' }

      it 'goes back to the drivers' do
        expect(dashboard.dimension).to eq('driver')
        expect(dashboard.rows.map(&:label)).to eq(['JOSE SILVA', 'MARIA SOUZA'])
      end
    end

    context 'when a trip has a km above the limit' do
      before do
        create_trip(code: 41_007, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 25, 8), distance_km: 5_001,
                    documents: [['74007', 400_000, 10, 'JOSE SILVA']])
      end

      it 'treats the km as invalid and keeps the trip out of the per km' do
        expect(dashboard.unmeasured_trips.map(&:code)).to eq([41_002, 41_007])
        expect(dashboard.per_km_base).to have_attributes(loaded_km: BigDecimal('650'), excluded_count: 2, excluded_gross: Money.from_cents(600_000))
        expect(row_values(dashboard.rows).first).to eq(
          ['JOSE SILVA', 3, 5651, 'R$ 13.000,00', 'R$ 12.000,00', 'R$ 4.333,33', 'R$ 4.000,00', 'R$ 13,85', 'R$ 12,31'],
        )
      end
    end

    context 'when a CT-e is listed again in a later MDF-e' do
      before do
        relist_documents(code: 41_008, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 23, 8), numbers: %w[74004])
        relist_documents(code: 41_009, plate: 'AAA1A11', started_at: Time.zone.local(2026, 10, 24, 8), numbers: %w[74006])
        relist_documents(code: 41_010, plate: 'BBB2B22', started_at: Time.zone.local(2026, 10, 26, 8), numbers: %w[74005])
      end

      def relist_documents(code:, plate:, started_at:, numbers:)
        create(:atua_manifest, tenant:, code:, number: code.to_s, plate:, status: 'Normal', trip_started_at: started_at)
        numbers.each do |number|
          create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: number, calculated_distance_km: 300)
        end
      end

      it 'counts the freight of the CT-e only in its first trip that was not canceled' do
        expect(Atua::Manifest.count).to eq(9)
        expect(row_values([dashboard.total])).to eq([['Total', 4, 950, 'R$ 20.000,00', 'R$ 19.000,00', 'R$ 5.000,00', 'R$ 4.750,00', 'R$ 18,95', 'R$ 17,89']])
        expect(dashboard.rows.flat_map(&:label)).to eq(['JOSE SILVA', 'MARIA SOUZA'])
      end
    end

    it 'has nothing to highlight with a single measured row' do
      expect(dashboard.highlights('net_per_km')).to eq({})
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
