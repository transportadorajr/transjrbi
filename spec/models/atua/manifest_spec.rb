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
        expect(described_class.by_situation('canceled')).to eq([canceled])
        expect(described_class.by_situation('valid')).to contain_exactly(open, closed, removed)
      end

      it 'keeps out manifests removed from Atua' do
        expect(described_class.active).to contain_exactly(open, closed, canceled)
      end
    end
  end

  describe '.statuses' do
    it 'maps the translated situations to the filter keys' do
      expect(described_class.statuses).to eq('Válido' => :valid, 'Cancelado' => :canceled)
    end
  end
end
