require 'rails_helper'

RSpec.describe Dashboard::Freight do
  subject(:dashboard) do
    described_class.new(tenant.atua_transport_documents,
                        manifests: tenant.atua_manifests, dimension:, period: october)
  end

  let!(:tenant) { create(:tenant) }
  let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }
  let(:dimension) { 'vehicle' }

  context 'without documents in the period' do
    it 'is empty' do
      expect(dashboard).to be_empty
      expect(dashboard.rows).to eq([])
      expect(dashboard.unlinked_gross).to eq(Money.from_cents(0))
      expect(dashboard.gross).to eq(Money.from_cents(0))
      expect(dashboard.total).to have_attributes(trips_count: 0, loaded_km: 0, gross: Money.from_cents(0), net: Money.from_cents(0),
                                                 gross_per_km: nil, net_per_km: nil, share: BigDecimal('0'))
    end
  end

  context 'with trips, complements and documents left out' do
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:grouped_taker) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
    let!(:loose_taker) { create(:atua_customer, tenant:, code: 7200) }

    let!(:first_trip) do
      create(:atua_manifest, tenant:, code: 41_001, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 2, 8))
    end
    let!(:second_trip) do
      create(:atua_manifest, tenant:, code: 41_002, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 10, 7))
    end
    let!(:repeated_trip) do
      create(:atua_manifest, tenant:, code: 41_003, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 20, 7))
    end
    let!(:canceled_trip) do
      create(:atua_manifest, tenant:, code: 41_004, plate: 'RVR7H89', status: 'Cancelado', trip_started_at: Time.zone.local(2026, 10, 3))
    end
    let!(:september_trip) do
      create(:atua_manifest, tenant:, code: 41_005, plate: 'RVR7H89', trip_started_at: Time.zone.local(2026, 9, 28, 9))
    end

    let!(:steel) do
      create(:atua_transport_document, tenant:, number: '74001', freight_cents: 1_000_000, posted_on: Date.new(2026, 9, 30),
                                       plate: 'RVR2C34', trailer_plate: 'RVR9C02', driver_code: 10, driver_name: 'JOSE SILVA',
                                       taker_code: 7100, origin_city: 'IPATINGA', origin_state: 'MG')
    end
    let!(:coil) do
      create(:atua_transport_document, tenant:, number: '74002', freight_cents: 500_000, plate: 'RVR2C34', trailer_plate: 'RVR9C02',
                                       driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7200, origin_city: 'IPATINGA',
                                       origin_state: 'MG')
    end
    let!(:plate) do
      create(:atua_transport_document, tenant:, number: '74003', freight_cents: 400_000, plate: 'RVR8J90', driver_code: 20,
                                       driver_name: 'MARIA SOUZA', taker_code: 7100, origin_city: 'BELO HORIZONTE', origin_state: 'MG')
    end
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '3547', document_kind: 'ce', freight_cents: 100_000,
                                       posted_on: Date.new(2026, 10, 15), plate: 'RVR8J90', driver_code: 20, driver_name: 'MARIA SOUZA',
                                       taker_code: 7100, origin_city: 'BELO HORIZONTE', origin_state: 'MG')
    end
    let!(:late_complement) do
      create(:atua_transport_document, tenant:, number: '3548', document_kind: 'ce', freight_cents: 90_000, posted_on: Date.new(2026, 11, 1))
    end
    let!(:unmanifested) { create(:atua_transport_document, tenant:, number: '74005', freight_cents: 900_000, posted_on: Date.new(2026, 10, 5)) }
    let!(:on_canceled_trip) { create(:atua_transport_document, tenant:, number: '74004', freight_cents: 800_000) }
    let!(:canceled) do
      create(:atua_transport_document, tenant:, number: '74006', freight_cents: 600_000, canceled_at: Time.zone.local(2026, 10, 3))
    end
    let!(:september) { create(:atua_transport_document, tenant:, number: '74007', freight_cents: 700_000, posted_on: Date.new(2026, 10, 1)) }

    before do
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74001',
                                      calculated_distance_km: 500, document_distance_km: 480)
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74002',
                                      calculated_distance_km: 300, document_distance_km: 520)
      create(:atua_manifest_document, tenant:, manifest_code: 41_001, transport_document_number: '74006',
                                      calculated_distance_km: 300, document_distance_km: 300)
      create(:atua_manifest_document, tenant:, manifest_code: 41_002, transport_document_number: '74003',
                                      calculated_distance_km: 200, document_distance_km: nil)
      create(:atua_manifest_document, tenant:, manifest_code: 41_003, transport_document_number: '74003',
                                      calculated_distance_km: 999, document_distance_km: 999)
      create(:atua_manifest_document, tenant:, manifest_code: 41_004, transport_document_number: '74004', calculated_distance_km: 100)
      create(:atua_manifest_document, tenant:, manifest_code: 41_005, transport_document_number: '74007', calculated_distance_km: 100)
      create(:empty_leg, tenant:, plate: 'RVR2C34', previous_manifest_code: 40_999, next_manifest_code: 41_001, distance_km: 80)
      create(:empty_leg, tenant:, plate: 'RVR8J90', previous_manifest_code: 41_002, next_manifest_code: 41_003, distance_km: 70)

      create(:freight_expense, tenant:, transport_document: steel, amount_cents: 20_000)
      create(:freight_expense, :tonnage, tenant:, transport_document: steel, amount_cents: 30_000)
      create(:atua_expense, tenant:, cost_object: steel, history_code: 72, total_cents: 15_000)
      create(:atua_expense, tenant:, cost_object: steel, total_cents: 99_000, removed_from_atua_at: Time.current)
      create(:atua_expense, tenant:, cost_object: nil, total_cents: 88_000)

      other_tenant = create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra')
      create(:atua_manifest, tenant: other_tenant, code: 41_001, plate: 'OUT1A11', trip_started_at: Time.zone.local(2026, 10, 2))
      create(:atua_transport_document, tenant: other_tenant, number: '74001', freight_cents: 5_000_000)
      create(:atua_manifest_document, tenant: other_tenant, manifest_code: 41_001, transport_document_number: '74001',
                                      calculated_distance_km: 50)
    end

    it 'sums the gross and net freight of the trips and of the complements, dividing only by the loaded km of the trips' do
      expect(Atua::TransportDocument.count).to eq(10)
      expect(dashboard.total).to have_attributes(
        label: 'Total',
        trips_count: 2,
        loaded_km: BigDecimal('720'),
        gross: Money.from_cents(2_000_000),
        freight_expenses: Money.from_cents(50_000),
        expenses: Money.from_cents(15_000),
        toll: Money.from_cents(0),
        net: Money.from_cents(1_935_000),
        gross_per_km: Money.from_cents(2_639),
        net_per_km: Money.from_cents(2_549),
        share: BigDecimal('100'),
      )
    end

    context 'with documents linked to no trip' do
      let!(:unlinked_in_november) do
        create(:atua_transport_document, tenant:, number: '74008', freight_cents: 300_000, posted_on: Date.new(2026, 11, 1))
      end
      let!(:unlinked_canceled) do
        create(:atua_transport_document, tenant:, number: '74009', freight_cents: 200_000, canceled_at: Time.zone.local(2026, 10, 3))
      end

      it 'adds the freight of the documents issued in the period without a trip to the gross freight of the trips' do
        expect(Atua::TransportDocument.where(tenant:).count).to eq(11)
        expect(dashboard.unlinked_gross).to eq(Money.from_cents(1_700_000))
        expect(dashboard.total.gross).to eq(Money.from_cents(2_000_000))
        expect(dashboard.gross).to eq(Money.from_cents(3_700_000))
      end
    end

    it 'groups by the truck and trailer plates' do
      expect(dashboard.rows.map(&:to_h)).to eq(
        [
          { label: 'RVR2C34 + RVR9C02', trips_count: 1, loaded_km: BigDecimal('520'), gross: Money.from_cents(1_500_000),
            freight_expenses: Money.from_cents(50_000), expenses: Money.from_cents(15_000), toll: Money.from_cents(0),
            net: Money.from_cents(1_435_000), gross_per_km: Money.from_cents(2_885), net_per_km: Money.from_cents(2_760),
            share: BigDecimal('75') },
          { label: 'RVR8J90', trips_count: 1, loaded_km: BigDecimal('200'), gross: Money.from_cents(500_000),
            freight_expenses: Money.from_cents(0), expenses: Money.from_cents(0), toll: Money.from_cents(0), net: Money.from_cents(500_000),
            gross_per_km: Money.from_cents(2_000), net_per_km: Money.from_cents(2_000), share: BigDecimal('25') },
        ],
      )
    end

    context 'when grouped by driver' do
      let(:dimension) { 'driver' }

      it 'labels each row with the driver name' do
        expect(dashboard.rows.map { |row| [row.label, row.trips_count, row.gross.cents] })
          .to eq([['JOSE SILVA', 1, 1_500_000], ['MARIA SOUZA', 1, 500_000]])
      end
    end

    context 'when grouped by customer group' do
      let(:dimension) { 'customer_group' }

      it 'splits a shared trip between the groups by their share of its freight' do
        expect(dashboard.rows.map { |row| [row.label, row.trips_count, row.loaded_km, row.gross.cents] }).to eq(
          [
            ['USIMINAS', BigDecimal('1.67'), BigDecimal('546.67'), 1_500_000],
            ['Sem grupo', BigDecimal('0.33'), BigDecimal('173.33'), 500_000],
          ],
        )
        expect(dashboard.total).to have_attributes(trips_count: 2, loaded_km: BigDecimal('720'))
      end
    end

    context 'when grouped by origin' do
      let(:dimension) { 'origin' }

      it 'labels each row with the origin city and state' do
        expect(dashboard.rows.map { |row| [row.label, row.gross.cents, row.share] })
          .to eq([['IPATINGA/MG', 1_500_000, BigDecimal('75')], ['BELO HORIZONTE/MG', 500_000, BigDecimal('25')]])
      end
    end

    context 'when grouped by macro region' do
      let(:dimension) { 'macro_region' }

      before do
        create(:macro_region, tenant:)
        MacroRegions::AssignCommand.call(tenant)
      end

      it 'labels each row with the region of the origin and puts the other origins in other regions' do
        expect(dashboard.rows.map { |row| [row.label, row.gross.cents, row.share] })
          .to eq([['VALE DO AÇO/MG', 1_500_000, BigDecimal('75')], ['Outras Regiões', 500_000, BigDecimal('25')]])
      end
    end

    context 'with an unknown dimension' do
      let(:dimension) { 'payer' }

      it 'falls back to the truck and trailer plates' do
        expect(dashboard.dimension).to eq('vehicle')
      end
    end

    it 'plots the ranking with the gross and the net freight' do
      expect(dashboard.ranking_data).to eq(
        [
          { name: 'Frete bruto', data: { 'RVR2C34 + RVR9C02' => 15_000.0, 'RVR8J90' => 5_000.0 } },
          { name: 'Frete líquido', data: { 'RVR2C34 + RVR9C02' => 14_350.0, 'RVR8J90' => 5_000.0 } },
        ],
      )
    end

    it 'plots the last six months by the trip date' do
      expect(dashboard.history_period).to eq(Date.new(2026, 5, 1)..Date.new(2026, 10, 31))
      expect(dashboard.monthly_data).to eq(
        [
          { name: 'Frete bruto',
            data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 7_000.0,
                    'Out/2026' => 20_000.0 } },
          { name: 'Frete líquido',
            data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 7_000.0,
                    'Out/2026' => 19_350.0 } },
        ],
      )
    end
  end

  context 'with a trip that loads in two cities and has no calculated empty km' do
    before do
      create(:atua_manifest, tenant:, code: 42_001, plate: 'RVR1A11', trip_started_at: Time.zone.local(2026, 10, 5, 6))
      create(:atua_transport_document, tenant:, number: '75001', freight_cents: 600_000, issued_at: Time.zone.local(2026, 10, 4, 10),
                                       plate: 'RVR1A11', trailer_plate: 'RVR1B22', driver_code: 30, driver_name: 'ANA LIMA',
                                       origin_city: 'CASCAVEL', origin_state: 'PR')
      create(:atua_transport_document, tenant:, number: '75002', freight_cents: 900_000, issued_at: Time.zone.local(2026, 10, 4, 14),
                                       plate: 'RVR1A11', trailer_plate: 'RVR1B22', driver_code: 31, driver_name: 'PEDRO ROCHA',
                                       origin_city: 'CAMPO MOURAO', origin_state: 'PR')
      create(:atua_manifest_document, tenant:, manifest_code: 42_001, transport_document_number: '75001', calculated_distance_km: 450)
      create(:atua_manifest_document, tenant:, manifest_code: 42_001, transport_document_number: '75002', calculated_distance_km: 380)
      create(:empty_leg, tenant:, plate: 'RVR1A11', previous_manifest_code: 41_999, next_manifest_code: 42_001,
                         status_type: 'unrouted', distance_km: nil)
    end

    it 'counts a single trip and divides only by its loaded km' do
      expect(Atua::TransportDocument.count).to eq(2)
      expect(dashboard.total).to have_attributes(trips_count: 1, loaded_km: BigDecimal('450'), gross: Money.from_cents(1_500_000),
                                                 gross_per_km: Money.from_cents(3_333))
    end

    context 'when grouped by origin' do
      let(:dimension) { 'origin' }

      it 'assigns the whole trip to the city of its first loading' do
        expect(dashboard.rows.map { |row| [row.label, row.trips_count, row.gross.cents] }).to eq([['CASCAVEL/PR', 1, 1_500_000]])
      end
    end

    context 'when grouped by macro region' do
      let(:dimension) { 'macro_region' }

      before do
        create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', cities: %w[Cascavel Corbélia])
        MacroRegions::AssignCommand.call(tenant)
      end

      it 'assigns the whole trip to the region of its first loading' do
        expect(dashboard.rows.map { |row| [row.label, row.trips_count, row.gross.cents] }).to eq([['OESTE PARANA', 1, 1_500_000]])
      end
    end

    context 'when grouped by driver' do
      let(:dimension) { 'driver' }

      it 'assigns the whole trip to the driver of its largest freight' do
        expect(dashboard.rows.map { |row| [row.label, row.trips_count, row.gross.cents] }).to eq([['PEDRO ROCHA', 1, 1_500_000]])
      end
    end
  end

  context 'with trips of an own truck and of a third party truck' do
    before do
      create(:atua_manifest, tenant:, code: 43_001, plate: 'RVR3D45', trip_started_at: Time.zone.local(2026, 10, 6, 8))
      create(:atua_manifest, tenant:, code: 43_002, plate: 'RVR3D45', trip_started_at: Time.zone.local(2026, 4, 14, 8))
      create(:atua_manifest, tenant:, code: 43_003, plate: 'PUR1A81', trip_started_at: Time.zone.local(2026, 10, 8, 8))
      create(:atua_transport_document, tenant:, number: '76001', freight_cents: 1_000_000, plate: 'RVR3D45', vehicle_ownership: 'Próprio')
      create(:atua_transport_document, tenant:, number: '76002', freight_cents: 500_000, plate: 'PUR1A81', vehicle_ownership: 'Terceiro')
      create(:atua_manifest_document, tenant:, manifest_code: 43_001, transport_document_number: '76001', calculated_distance_km: 400)
      create(:atua_manifest_document, tenant:, manifest_code: 43_002, transport_document_number: '75900', calculated_distance_km: 500)
      create(:atua_manifest_document, tenant:, manifest_code: 43_003, transport_document_number: '76002', calculated_distance_km: 250)
      create(:empty_leg, tenant:, plate: 'RVR3D45', previous_manifest_code: 43_002, next_manifest_code: 43_001, distance_km: 100)
      create(:atua_expense, tenant:, plate: 'RVR3D45', history_code: 11, document_on: Date.new(2026, 5, 2), total_cents: 300_000)
      create(:atua_expense, tenant:, plate: 'RVR3D45', history_code: 396, document_on: Date.new(2026, 10, 7), total_cents: 20_000)
      create(:atua_expense, tenant:, plate: 'PUR1A81', history_code: 11, document_on: Date.new(2026, 10, 8), total_cents: 50_000)
    end

    it 'does not discount the fuel nor count the empty km of the own truck' do
      expect(Atua::Expense.count).to eq(3)
      expect(dashboard.rows.map { |row| [row.label, row.loaded_km, row.net.cents] })
        .to eq([['RVR3D45', BigDecimal('400'), 1_000_000], ['PUR1A81', BigDecimal('250'), 500_000]])
      expect(dashboard.total).to have_attributes(gross: Money.from_cents(1_500_000), net: Money.from_cents(1_500_000),
                                                 net_per_km: Money.from_cents(2_308))
      expect(dashboard.monthly_data.last[:data]['Out/2026']).to eq(15_000.0)
    end
  end

  context 'with trips carrying tolls inside and outside the gross freight' do
    before do
      create(:atua_manifest, tenant:, code: 44_001, plate: 'RVR4E56', trip_started_at: Time.zone.local(2026, 10, 9, 8))
      create(:atua_manifest, tenant:, code: 44_002, plate: 'RVR5F67', trip_started_at: Time.zone.local(2026, 10, 12, 8))
      create(:atua_transport_document, tenant:, number: '77001', freight_cents: 1_000_000, weight_freight_cents: 850_000,
                                       toll_cents: 30_000, icms_cents: 120_000, plate: 'RVR4E56')
      create(:atua_transport_document, tenant:, number: '77002', freight_cents: 500_000, weight_freight_cents: 500_000,
                                       toll_cents: 40_000, icms_cents: 0, plate: 'RVR5F67')
      create(:atua_transport_document, tenant:, number: '77003', document_kind: 'ce', freight_cents: 60_000, weight_freight_cents: 55_000,
                                       toll_cents: 5_000, icms_cents: 0, posted_on: Date.new(2026, 10, 20), plate: 'RVR4E56')
      create(:atua_manifest_document, tenant:, manifest_code: 44_001, transport_document_number: '77001', calculated_distance_km: 400)
      create(:atua_manifest_document, tenant:, manifest_code: 44_002, transport_document_number: '77002', calculated_distance_km: 250)
    end

    it 'discounts only the toll already carried by the gross freight of the documents' do
      expect(Atua::TransportDocument.count).to eq(3)
      expect(dashboard.rows.map { |row| [row.label, row.gross.cents, row.toll.cents, row.net.cents] })
        .to eq([['RVR4E56', 1_060_000, 35_000, 1_025_000], ['RVR5F67', 500_000, 0, 500_000]])
      expect(dashboard.total).to have_attributes(gross: Money.from_cents(1_560_000), toll: Money.from_cents(35_000),
                                                 net: Money.from_cents(1_525_000), net_per_km: Money.from_cents(2_262))
      expect(dashboard.monthly_data.last[:data]['Out/2026']).to eq(15_250.0)
    end
  end

  context 'with a period that ends before the end of the month' do
    let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 15) }

    before do
      create(:atua_manifest, tenant:, code: 45_001, plate: 'RVR6G78', trip_started_at: Time.zone.local(2026, 10, 10, 8))
      create(:atua_manifest, tenant:, code: 45_002, plate: 'RVR6G78', trip_started_at: Time.zone.local(2026, 10, 25, 8))
      create(:atua_transport_document, tenant:, number: '78001', freight_cents: 400_000, plate: 'RVR6G78')
      create(:atua_transport_document, tenant:, number: '78002', freight_cents: 600_000, plate: 'RVR6G78')
      create(:atua_manifest_document, tenant:, manifest_code: 45_001, transport_document_number: '78001', calculated_distance_km: 200)
      create(:atua_manifest_document, tenant:, manifest_code: 45_002, transport_document_number: '78002', calculated_distance_km: 300)
    end

    it 'plots the whole last month while the totals keep only the period' do
      expect(Atua::TransportDocument.count).to eq(2)
      expect(dashboard.total).to have_attributes(trips_count: 1, gross: Money.from_cents(400_000))
      expect(dashboard.history_period).to eq(Date.new(2026, 5, 1)..Date.new(2026, 10, 31))
      expect(dashboard.monthly_data.first[:data]['Out/2026']).to eq(10_000.0)
    end
  end

  context 'with a trip started late at night on the last day of the month' do
    before do
      create(:atua_manifest, tenant:, code: 41_010, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 31, 22, 30))
      create(:atua_transport_document, tenant:, number: '74010', freight_cents: 300_000, posted_on: Date.new(2026, 11, 2))
      create(:atua_manifest_document, tenant:, manifest_code: 41_010, transport_document_number: '74010', calculated_distance_km: 150)
    end

    it 'keeps the trip in the local day it started' do
      expect(dashboard.total).to have_attributes(trips_count: 1, gross: Money.from_cents(300_000), loaded_km: BigDecimal('150'))
    end
  end

  context 'with documents of excluded issuers' do
    subject(:dashboard) do
      described_class.new(tenant.atua_transport_documents.without_issuers(tenant.excluded_issuers.select(:code)),
                          manifests: tenant.atua_manifests, dimension:, period: october)
    end

    before do
      create(:excluded_issuer, tenant:, code: 6190)
      create(:atua_manifest, tenant:, code: 45_001, plate: 'RVR6G78', trip_started_at: Time.zone.local(2026, 9, 14, 8))
      create(:atua_manifest, tenant:, code: 45_002, plate: 'RVR6G78', trip_started_at: Time.zone.local(2026, 10, 6, 8))
      create(:atua_transport_document, tenant:, number: '78001', issuer_code: 6001, freight_cents: 700_000, plate: 'RVR6G78')
      create(:atua_transport_document, tenant:, number: '78002', issuer_code: 6190, freight_cents: 900_000, plate: 'RVR6G78')
      create(:atua_transport_document, tenant:, number: '78003', issuer_code: 6001, freight_cents: 400_000, plate: 'RVR6G78')
      create(:atua_transport_document, tenant:, number: '4267', document_kind: 'ce', issuer_code: 6190, freight_cents: 1_657_920,
                                       issued_at: Time.zone.local(2026, 8, 25, 10), posted_on: Date.new(2026, 10, 2))
      create(:atua_transport_document, tenant:, number: '4300', document_kind: 'ce', issuer_code: 6190, freight_cents: 500_000,
                                       issued_at: Time.zone.local(2026, 9, 3, 10), posted_on: Date.new(2026, 9, 4))
      create(:atua_manifest_document, tenant:, manifest_code: 45_001, transport_document_number: '78001', calculated_distance_km: 400)
      create(:atua_manifest_document, tenant:, manifest_code: 45_001, transport_document_number: '78002', calculated_distance_km: 400)
      create(:atua_manifest_document, tenant:, manifest_code: 45_002, transport_document_number: '78003', calculated_distance_km: 300)
    end

    it 'leaves them out of the monthly evolution' do
      expect(dashboard.gross).to eq(Money.from_cents(400_000))
      expect(dashboard.monthly_data).to eq(
        [
          { name: 'Frete bruto',
            data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 7_000.0,
                    'Out/2026' => 4_000.0 } },
          { name: 'Frete líquido',
            data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 7_000.0,
                    'Out/2026' => 4_000.0 } },
        ],
      )
      expect(Atua::TransportDocument.count).to eq(5)
    end
  end
end
