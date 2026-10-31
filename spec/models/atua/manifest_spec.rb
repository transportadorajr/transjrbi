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
  end

  describe '#previous_trip' do
    let!(:first_trip) { create(:atua_manifest, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 1, 8)) }
    let!(:second_trip) { create(:atua_manifest, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 3, 8)) }
    let!(:third_trip) { create(:atua_manifest, tenant:, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 5, 8)) }

    before do
      create(:atua_manifest, tenant:, plate: 'RHJ4E07', status: 'Cancelado', trip_started_at: Time.zone.local(2026, 10, 4, 8))
      create(:atua_manifest, tenant:, plate: 'RHJ4E07', removed_from_atua_at: Time.current, trip_started_at: Time.zone.local(2026, 10, 4, 9))
      create(:atua_manifest, tenant:, plate: 'QWE1A23', trip_started_at: Time.zone.local(2026, 10, 4, 10))
      create(:atua_manifest, tenant: other_tenant, plate: 'RHJ4E07', trip_started_at: Time.zone.local(2026, 10, 4, 11))
    end

    it 'returns the latest valid trip of the same plate that started before' do
      expect(third_trip.previous_trip).to eq(second_trip)
      expect(second_trip.previous_trip).to eq(first_trip)
    end

    it 'returns nothing for the first trip of the plate' do
      expect(first_trip.previous_trip).to be_nil
    end

    it 'falls back to the departure date when the trip start is missing' do
      trip = create(:atua_manifest, tenant:, plate: 'RHJ4E07', trip_started_at: nil, departure_on: Date.new(2026, 10, 2), issued_on: Date.new(2026, 10, 2))

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
