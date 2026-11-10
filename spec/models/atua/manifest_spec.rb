require 'rails_helper'

RSpec.describe Atua::Manifest do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with documents, transport documents and a vehicle of the same tenant' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_236, number: '40772', branch_name: 'JR TRANSPORTES', plate: 'RHJ4E07') }
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'RHJ4E07') }
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, code: 80_001, number: '74130', series: 1, branch_name: 'JR TRANSPORTES')
      end
      let!(:document) do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES')
      end
      let!(:link) do
        create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_001, manifest_number: '40772',
                                                  branch_name: 'JR TRANSPORTES')
      end

      before do
        create(:atua_vehicle, tenant: other_tenant, plate: 'RHJ4E07')
        create(:atua_manifest_document, tenant: other_tenant, manifest_code: 41_236)
        create(:atua_transport_document_manifest, tenant: other_tenant, manifest_number: '40772', branch_name: 'JR TRANSPORTES')
        create(:atua_transport_document_manifest, tenant:, manifest_number: '40772', branch_name: 'TRANSJR SABARA')
      end

      it 'lists its documents inside the tenant' do
        expect(manifest.documents).to eq([document])
        expect(Atua::ManifestDocument.count).to eq(2)
      end

      it 'reaches the transport documents through its documents' do
        expect(manifest.transport_documents).to eq([transport_document])
      end

      it 'lists the transport document links by number and branch' do
        expect(manifest.transport_document_manifests).to eq([link])
        expect(Atua::TransportDocumentManifest.count).to eq(3)
      end

      it 'links the vehicle by plate inside the tenant' do
        expect(manifest.vehicle).to eq(vehicle)
      end

      it 'preloads the documents and transport documents' do
        loaded = described_class.where(tenant:).preload(documents: :transport_document).first

        expect(loaded.association(:documents)).to be_loaded
        expect(loaded.documents.first.transport_document).to eq(transport_document)
      end
    end
  end

  describe 'validations' do
    context 'with a manifest already imported' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_236) }

      it 'rejects the same code in the same tenant' do
        duplicated = build(:atua_manifest, tenant:, code: 41_236)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:atua_manifest, tenant: other_tenant, code: manifest.code)).to be_valid
      end
    end
  end

  describe 'scopes' do
    context 'with manifests of different periods, plates and situations' do
      let!(:open) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 10, 1), departure_on: Date.new(2026, 10, 2), plate: 'RHJ4E07', status: 'Normal') }
      let!(:closed) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 10, 13), departure_on: Date.new(2026, 10, 14), plate: 'EXU0F72', status: 'Encerrado') }
      let!(:canceled) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 9, 30), departure_on: Date.new(2026, 10, 1), plate: 'RHJ4E07', status: 'Cancelado') }
      let!(:removed) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 10, 5), departure_on: nil, plate: 'AGL9451', status: nil, removed_from_atua_at: Time.current) }

      it 'filters by the emission period' do
        expect(described_class.by_period('2026-10-01', '2026-10-13')).to contain_exactly(open, closed, removed)
        expect(described_class.count).to eq(4)
      end

      it 'filters by the departure period' do
        expect(described_class.by_departure_period('2026-10-01', '2026-10-02')).to contain_exactly(open, canceled)
      end

      it 'filters by plate' do
        expect(described_class.by_plate('rhj 4e07')).to contain_exactly(open, canceled)
      end

      it 'filters by situation' do
        expect(described_class.by_status('Encerrado')).to eq([closed])
      end

      it 'keeps out canceled manifests' do
        expect(described_class.not_canceled).to contain_exactly(open, closed, removed)
        expect(canceled).to be_canceled
      end

      it 'filters by the start or the end of the emission period' do
        expect(described_class.by_period_start('2026-10-05')).to contain_exactly(closed, removed)
        expect(described_class.by_period_end('2026-10-01')).to contain_exactly(open, canceled)
      end

      it 'filters by the number' do
        expect(described_class.by_number(" #{closed.number} ")).to eq([closed])
      end

      it 'filters by the situation' do
        expect(described_class.canceled).to eq([canceled])
      end

      it 'keeps out manifests removed from Atua' do
        expect(described_class.active).to contain_exactly(open, closed, canceled)
      end
    end
  end

  describe 'filters by the transport documents of the manifest' do
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
    let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
    let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA') }
    let!(:rodotrem) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }
    let!(:jose_trip) { create(:atua_manifest, tenant:, code: 41_001, number: '40801', branch_name: 'JR') }
    let!(:maria_trip) { create(:atua_manifest, tenant:, code: 41_002, number: '40802', branch_name: 'JR') }
    let!(:empty_trip) { create(:atua_manifest, tenant:, code: 41_003, number: '40803', branch_name: 'JR') }
    let!(:stranger_trip) { create(:atua_manifest, tenant: other_tenant, code: 41_001, number: '40801', branch_name: 'JR') }

    def add_document(manifest, number, **attributes)
      create(:atua_transport_document, tenant: manifest.tenant, number:, series: 1, branch_name: 'JR', **attributes)
      create(:atua_manifest_document, tenant: manifest.tenant, manifest_code: manifest.code, transport_document_number: number,
                                      transport_document_series: 1, branch_name: 'JR')
    end

    before do
      add_document(jose_trip, '1', driver_code: 10, axles: 9, taker_code: usiminas_customer.code, product_group_id: coil.id)
      add_document(maria_trip, '2', driver_code: 20, axles: 6, taker_code: 7200)
      add_document(maria_trip, '3', driver_code: 10, axles: 9, canceled_at: Time.current)
      add_document(stranger_trip, '1', driver_code: 10, axles: 9, taker_code: 7100)
    end

    it 'keeps only the manifests with a valid transport document of the driver' do
      expect(described_class.where(tenant:).by_driver(10)).to eq([jose_trip])
      expect(described_class.where(tenant:).by_driver(20)).to eq([maria_trip])
      expect(described_class.count).to eq(4)
    end

    it 'keeps only the manifests with a transport document of the customer or of the customer group' do
      expect(described_class.where(tenant:).by_taker(7100)).to eq([jose_trip])
      expect(described_class.where(tenant:).by_customer_group(usiminas.id)).to eq([jose_trip])
    end

    it 'keeps only the manifests with a transport document of a subgroup of the product group' do
      expect(described_class.where(tenant:).by_product_group(steel.id)).to eq([jose_trip])
    end

    it 'keeps only the manifests with a transport document of the product' do
      expect(described_class.where(tenant:).by_product(coil.id)).to eq([jose_trip])
      expect(described_class.where(tenant:).by_product(steel.id)).to eq([])
    end

    it 'keeps only the manifests with a transport document of the truck group' do
      expect(described_class.where(tenant:).by_truck_group(rodotrem, [])).to eq([jose_trip])
    end

    it 'does not match a manifest of another tenant with the same code' do
      expect(described_class.where(tenant: other_tenant).by_driver(20)).to be_empty
    end
  end

  describe '.with_freight_totals' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 41_600, branch_name: 'JR') }

    def add_document(number, document_freight, **attributes)
      create(:atua_manifest_document, tenant:, manifest_code: 41_600, transport_document_number: number, transport_document_series: 1, branch_name: 'JR',
                                      freight_cents: document_freight, **attributes)
    end

    def add_transport_document(number, freight_cents, **attributes)
      create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', freight_cents:, **attributes)
    end

    before do
      add_transport_document('1', 600_000)
      add_document('1', 500_000)
      add_transport_document('2', 900_000, canceled_at: Time.current)
      add_document('2', 900_000)
      add_transport_document('3', 700_000, removed_from_atua_at: Time.current)
      add_document('3', 700_000)
      add_document('4', 801_915)
      add_document('5', nil)
      add_document('6', 400_000, removed_from_atua_at: Time.current)
      add_transport_document('7', 250_000, series: 50)
      add_document('7', 300_000)
      add_transport_document('8', 350_000, canceled_at: Time.current, removed_from_atua_at: Time.current)
      add_document('8', 350_000)
      create(:atua_customer, tenant:, code: 777, document_digits: Atua::TransportDocument::INTERNAL_TAKER_DOCUMENTS.first)
      add_transport_document('9', 450_000, taker_code: 777, removed_from_atua_at: Time.current)
      add_document('9', 450_000)
    end

    it 'sums the transport documents and falls back to the manifest freight of the ones missing or removed from Atua' do
      expect(described_class.with_freight_totals.find(manifest.id).gross_cents).to eq(600_000 + 700_000 + 801_915 + 300_000)
    end

    it 'leaves the CEs of the manifest out of the gross freight' do
      add_transport_document('10', 990_000, document_kind: 'ce')
      add_document('10', 990_000)

      expect(described_class.with_freight_totals.find(manifest.id).gross_cents).to eq(600_000 + 700_000 + 801_915 + 300_000)
    end

    it 'exposes the manifest freight of the transport documents missing or removed from Atua' do
      expect(manifest.missing_documents_freight).to eq(Money.from_cents(700_000 + 801_915 + 300_000))
    end

    it 'keeps the manifest freight of a transport document removed from Atua in the trip totals' do
      totals = described_class.with_trip_totals(described_class.where(id: manifest.id)).first

      expect(totals.gross_cents).to eq(600_000 + 700_000 + 801_915 + 300_000)
      expect(totals.net_cents).to be_positive
    end
  end

  describe 'trip duration' do
    def create_trip(code, started_at:, closed_at:, freight_cents: 380_000)
      manifest = create(:atua_manifest, tenant:, code:, branch_name: 'JR', trip_started_at: started_at, closed_at:)
      create(:atua_transport_document, tenant:, number: code.to_s, series: 1, branch_name: 'JR', freight_cents:)
      create(:atua_manifest_document, tenant:, manifest_code: code, transport_document_number: code.to_s, transport_document_series: 1, branch_name: 'JR')
      manifest
    end

    context 'with closed, open and too short trips' do
      let!(:closed) { create_trip(41_601, started_at: Time.zone.local(2026, 10, 1, 8), closed_at: Time.zone.local(2026, 10, 3, 10)) }
      let!(:open) { create_trip(41_602, started_at: Time.zone.local(2026, 10, 5, 8), closed_at: nil) }
      let!(:short) { create_trip(41_603, started_at: Time.zone.local(2026, 10, 6, 8), closed_at: Time.zone.local(2026, 10, 6, 8, 30)) }

      it 'measures the closed trip from the start to the closing' do
        expect(closed.duration.hours).to eq(50)
        expect(closed).not_to be_in_progress
        expect(closed.elapsed).to be_nil
      end

      it 'shows the time elapsed so far of the trip in progress without a final duration' do
        travel_to(Time.zone.local(2026, 10, 6, 13)) do
          expect(open.duration).to be_nil
          expect(open).to be_in_progress
          expect(open.elapsed.hours).to eq(29)
        end
      end

      it 'calculates the duration and the net freight per hour of each trip' do
        totals = described_class.with_trip_totals(described_class.where(tenant:)).index_by(&:code)

        expect(totals[41_601].duration_seconds).to eq(50.hours.to_i)
        expect(totals[41_601].net_per_hour_cents).to eq(totals[41_601].net_cents * 3600 / 50.hours.to_i)
        expect(totals[41_602].duration_seconds).to be_nil
        expect(totals[41_602].net_per_hour_cents).to be_nil
        expect(totals[41_603].duration_seconds).to eq(30.minutes.to_i)
        expect(totals[41_603].net_per_hour_cents).to be_nil
      end

      it 'sorts the trips from the fastest leaving the trips in progress last' do
        totals = described_class.with_trip_totals(described_class.where(tenant:))

        expect(totals.sorted_by(:duration, :asc).map(&:code)).to eq([41_603, 41_601, 41_602])
        expect(totals.sorted_by(:duration, :desc).map(&:code)).to eq([41_601, 41_603, 41_602])
      end
    end
  end

  describe '#origins and #destinations' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 41_500, branch_name: 'JR') }
    let!(:internal_taker) { create(:atua_customer, tenant:, code: 777, document_digits: Atua::TransportDocument::INTERNAL_TAKER_DOCUMENTS.first) }

    def add_document(number, origin_city, destination_city, **attributes)
      create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', **attributes)
      create(:atua_manifest_document, tenant:, manifest_code: 41_500, transport_document_number: number, transport_document_series: 1, branch_name: 'JR',
                                      origin_city:, origin_state: 'MG', destination_city:, destination_state: 'SP')
    end

    before do
      add_document('1', 'Ipatinga', 'Santos')
      add_document('2', 'Ipatinga', 'Cubatão')
      add_document('3', 'Canceled', 'Canceled', canceled_at: Time.current)
      add_document('4', 'Removed', 'Removed', removed_from_atua_at: Time.current)
      add_document('5', 'Internal', 'Internal', taker_code: 777)
      add_document('6', nil, nil)
      create(:atua_manifest_document, tenant:, manifest_code: 41_500, transport_document_number: '7', transport_document_series: 1, branch_name: 'JR',
                                      origin_city: 'Betim', origin_state: 'MG', destination_city: 'Campinas', destination_state: 'SP')
      create(:atua_manifest_document, tenant:, manifest_code: 41_500, transport_document_number: '8', transport_document_series: 1, branch_name: 'JR',
                                      origin_city: 'Gone', origin_state: 'MG', destination_city: 'Gone', destination_state: 'SP', removed_from_atua_at: Time.current)
    end

    it 'lists each city once and keeps out the documents that are not part of the trip' do
      expect(manifest.origins).to eq([%w[Ipatinga MG], %w[Betim MG]])
      expect(manifest.destinations).to eq([%w[Santos SP], %w[Cubatão SP], %w[Campinas SP]])
    end

    it 'returns the destination of the last document of the trip as the final destination' do
      expect(manifest.final_destination).to eq(%w[Campinas SP])
    end

    it 'returns no final destination when no document of the trip has a destination' do
      other = create(:atua_manifest, tenant:, code: 41_501, branch_name: 'JR')

      expect(other.final_destination).to be_nil
    end
  end

  describe '#drivers and #weight_kg' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 41_510, branch_name: 'JR') }

    def add_document(number, driver_name, weight_kg, **attributes)
      create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', driver_name:, **attributes)
      create(:atua_manifest_document, tenant:, manifest_code: 41_510, transport_document_number: number, transport_document_series: 1,
                                      branch_name: 'JR', weight_kg:)
    end

    context 'when the trip has documents of the same driver and documents out of the trip' do
      before do
        add_document('1', 'JOÃO', BigDecimal('19170'))
        add_document('2', 'JOÃO', BigDecimal('10000.5'))
        add_document('3', 'MARIA', BigDecimal('5000'), canceled_at: Time.current)
        add_document('4', nil, nil)
        create(:atua_manifest_document, tenant:, manifest_code: 41_510, transport_document_number: '5', transport_document_series: 1,
                                        branch_name: 'JR', weight_kg: BigDecimal('1000'))
      end

      it 'lists each driver once and sums the weight of the documents on the trip' do
        expect(manifest.drivers).to eq(['JOÃO'])
        expect(manifest.weight_kg).to eq(BigDecimal('30170.5'))
      end
    end

    context 'when the documents have no driver nor weight' do
      before { add_document('1', nil, nil) }

      it 'returns no driver and no weight' do
        expect(manifest.drivers).to eq([])
        expect(manifest.weight_kg).to be_nil
      end
    end
  end

  describe '#main_driver_name' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 41_520, branch_name: 'JR') }

    def add_document(number, driver_code, driver_name, freight_cents, **attributes)
      create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', driver_code:, driver_name:, freight_cents:, **attributes)
      create(:atua_manifest_document, tenant:, manifest_code: 41_520, transport_document_number: number, transport_document_series: 1, branch_name: 'JR')
    end

    context 'when the trip has documents of different drivers' do
      before do
        add_document('1', 10, 'JOAO DA SILVA', 50_000)
        add_document('2', 20, 'MARIA SOUZA', 90_000)
        add_document('3', 30, 'PEDRO LIMA', 200_000, canceled_at: Time.current)
        add_document('4', 40, 'ANA COSTA', 300_000, document_kind: 'ce')
      end

      it 'returns the driver of the highest freight transport document on the trip' do
        expect(manifest.main_driver_name).to eq('MARIA SOUZA')
      end

      it 'returns the display name of the main driver when one is registered' do
        create(:driver, tenant:, code: 20, display_name: 'MARIA')

        expect(manifest.main_driver_name).to eq('MARIA')
      end
    end

    context 'when the documents have no driver' do
      before { add_document('1', nil, nil, 50_000) }

      it 'returns no driver' do
        expect(manifest.main_driver_name).to be_nil
      end
    end
  end

  describe '.with_transport_documents and .trips' do
    let!(:linked) { create(:atua_manifest, :with_transport_document, tenant:) }
    let!(:unlinked) { create(:atua_manifest, tenant:) }
    let!(:removed_link) { create(:atua_manifest, :with_transport_document, tenant:) }
    let!(:canceled_document) { create(:atua_manifest, tenant:) }

    before do
      create(:atua_manifest_document, tenant:, manifest_code: unlinked.code, transport_document_number: '69674')
      removed_link.documents.update_all(removed_from_atua_at: Time.current)
      transport_document = create(:atua_transport_document, tenant:, canceled_at: Time.current)
      create(:atua_manifest_document, tenant:, manifest_code: canceled_document.code, transport_document_number: transport_document.number)
      create(:atua_transport_document, tenant: other_tenant, number: '69674')
    end

    it 'keeps only the manifests linked to a transport document' do
      expect(described_class.where(tenant:).with_transport_documents).to contain_exactly(linked, canceled_document)
      expect(described_class.where(tenant:).trips).to contain_exactly(linked, canceled_document)
      expect(described_class.where(tenant:).count).to eq(4)
    end
  end

  describe '#previous_trip' do
    let!(:first_trip) { create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 1, 8)) }
    let!(:second_trip) { create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 3, 8)) }
    let!(:third_trip) { create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 5, 8)) }

    before do
      create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', status: 'Cancelado', trip_started_at: Time.zone.local(2026, 10, 4, 8))
      create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', removed_from_atua_at: Time.current, trip_started_at: Time.zone.local(2026, 10, 4, 9))
      create(:atua_manifest, :with_transport_document, tenant:, plate: 'QWE1A23', trip_started_at: Time.zone.local(2026, 10, 4, 10))
      create(:atua_manifest, :with_transport_document, tenant: other_tenant, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 4, 11))
      create(:atua_manifest, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 4, 12))
    end

    it 'returns the latest valid trip of the same plate that started before' do
      expect(third_trip.previous_trip).to eq(second_trip)
      expect(second_trip.previous_trip).to eq(first_trip)
    end

    it 'returns nothing for the first trip of the plate' do
      expect(first_trip.previous_trip).to be_nil
    end

    it 'falls back to the departure date when the trip start is missing' do
      trip = create(:atua_manifest, :with_transport_document, tenant:, plate: 'RHJ4E07', trip_started_at: nil, departure_on: Date.new(2026, 10, 2), issued_on: Date.new(2026, 10, 2))

      expect(second_trip.previous_trip).to eq(trip)
      expect(trip.previous_trip).to eq(first_trip)
    end
  end

  describe '#trip_on' do
    it 'uses the trip start, then the departure and then the issue date' do
      expect(build(:atua_manifest, trip_started_at: Time.zone.local(2026, 10, 3, 23), departure_on: Date.new(2026, 10, 2)).trip_on)
        .to eq(Date.new(2026, 10, 3))
      expect(build(:atua_manifest, trip_started_at: nil, departure_on: Date.new(2026, 10, 2)).trip_on).to eq(Date.new(2026, 10, 2))
      expect(build(:atua_manifest, trip_started_at: nil, departure_on: nil, issued_on: Date.new(2026, 10, 1)).trip_on).to eq(Date.new(2026, 10, 1))
    end
  end

  describe '#ordered_documents' do
    let!(:manifest) { create(:atua_manifest, tenant:, code: 41_500, branch_name: 'JR TRANSPORTES') }
    let!(:late) { create(:atua_transport_document, tenant:, number: '74002', branch_name: 'JR TRANSPORTES', issued_at: Time.zone.local(2026, 10, 1, 18)) }
    let!(:early) { create(:atua_transport_document, tenant:, number: '74001', branch_name: 'JR TRANSPORTES', issued_at: Time.zone.local(2026, 10, 1, 9)) }
    let!(:canceled) do
      create(:atua_transport_document, tenant:, number: '74003', branch_name: 'JR TRANSPORTES', issued_at: Time.zone.local(2026, 10, 1, 7),
                                       canceled_at: Time.zone.local(2026, 10, 1, 8))
    end

    before do
      [late, early, canceled].each do |document|
        create(:atua_manifest_document, tenant:, manifest_code: 41_500, transport_document_number: document.number,
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES')
      end
    end

    it 'sorts the documents by the transport document issue and skips the canceled ones' do
      expect(manifest.ordered_documents.map(&:transport_document_number)).to eq(%w[74001 74002])
    end
  end
end
