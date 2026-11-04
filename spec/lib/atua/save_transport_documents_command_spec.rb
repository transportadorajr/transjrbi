require 'rails_helper'

RSpec.describe Atua::SaveTransportDocumentsCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'transport_documents', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:transport_documents) }

  context 'with a manifest link of an imported document that is no longer in the file' do
    let!(:stale) { create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '1') }

    it 'replaces the manifest links with the manifest numbers of the file' do
      result = described_class.call(import, spreadsheet)

      expect(result).to have_attributes(inserted: 420, updated: 0, removed: 0)
      expect(Atua::TransportDocumentManifest.exists?(stale.id)).to be(false)
      expect(tenant.atua_transport_document_manifests.where(transport_document_code: 80_842).pluck(:manifest_number, :branch_name, :raw_data))
        .to eq([['183', 'EMPRESA 01', { 'nr_mdfe' => 183.0 }]])
    end
  end

  context 'with a Transjr CNPJ among the takers of the file' do
    let(:first_record) { Atua::MapTransportDocumentsCommand.call(tenant, spreadsheet).first }
    let!(:taker) { create(:atua_customer, tenant:, code: first_record[:taker_code], document_digits: '51628145000172') }

    it 'leaves the documents of that taker out of the active ones' do
      described_class.call(import, spreadsheet)

      expect(tenant.atua_transport_documents.active.where(taker_code: taker.code)).to be_empty
      expect(tenant.atua_transport_documents.where(taker_code: taker.code)).to exist
    end
  end

  context 'with a document of an excluded plate in the file' do
    let!(:first_record) { Atua::MapTransportDocumentsCommand.call(tenant, spreadsheet).first }

    before do
      allow(Atua::MapTransportDocumentsCommand).to receive(:call).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).map { |attributes| attributes[:code] == first_record[:code] ? attributes.merge(plate: 'BAM2A26') : attributes }
      end
    end

    it 'leaves the document out of the active ones' do
      described_class.call(import, spreadsheet)

      expect(tenant.atua_transport_documents.active.where(plate: 'BAM2A26')).to be_empty
      expect(tenant.atua_transport_documents.find_by!(code: first_record[:code]).removed_from_atua_at).to be_present
    end
  end

  context 'with macro regions of the tenant' do
    let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: %w[Corbélia Cascavel]) }
    let!(:interior) { create(:macro_region, :interior_sp, tenant:) }

    it 'assigns the macro region of the origin of the imported documents' do
      described_class.call(import, spreadsheet)

      documents = tenant.atua_transport_documents
      expect(documents.where(origin_city: 'CORBELIA').pluck(:origin_macro_region_id).uniq).to eq([oeste_parana.id])
      expect(documents.where(origin_city: 'SANTA GERTRUDES').pluck(:origin_macro_region_id).uniq).to eq([interior.id])
      expect(documents.where(origin_city: 'JUIZ DE FORA').pluck(:origin_macro_region_id).uniq)
        .to eq([tenant.macro_regions.find_by!(name: 'RESTO DE MINAS GERAIS').id])
    end

    it 'registers the new origin cities in the remaining state region of their state' do
      described_class.call(import, spreadsheet)

      juiz_de_fora = tenant.cities.find_by!(name: 'JUIZ DE FORA', state: 'MG')
      expect(juiz_de_fora.macro_region).to have_attributes(name: 'RESTO DE MINAS GERAIS', state: 'MG', remaining_state: true)
      expect(tenant.cities.where(name: 'CORBELIA')).to be_empty
      expect(tenant.cities.find_by!(name: 'SANTA GERTRUDES').macro_region).to eq(interior)
    end
  end

  context 'with product groups of the tenant' do
    let(:product_name) { Atua::MapTransportDocumentsCommand.call(tenant, spreadsheet).filter_map { |record| record[:product_name] }.first }
    let!(:subgroup) { create(:product_subgroup, tenant:, product_names: [product_name]) }

    it 'classifies the imported documents by their product' do
      described_class.call(import, spreadsheet)

      documents = tenant.atua_transport_documents
      expect(documents.where(product_name:).pluck(:product_group_id).uniq).to eq([subgroup.id])
      expect(documents.where.not(product_name:).where.not(product_group_id: nil)).to be_empty
    end
  end

  context 'with a distance adjustment registered before the document arrives' do
    let(:first_record) { Atua::MapTransportDocumentsCommand.call(tenant, spreadsheet).first }
    let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: first_record[:number].to_s, distance_km: BigDecimal('1300')) }

    it 'replaces the distance of the imported document keeping the distance from Atua' do
      described_class.call(import, spreadsheet)

      document = tenant.atua_transport_documents.find_by!(code: first_record[:code])
      expect(document).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: first_record[:distance_km])
      expect(document.distance_adjusted_at).to be_present
      expect(adjustment.reload.applied_at).to be_present
    end
  end

  context 'with a document whose distance was adjusted' do
    let(:first_record) { Atua::MapTransportDocumentsCommand.call(tenant, spreadsheet).first }
    let(:adjusted_at) { Time.zone.local(2026, 10, 20, 9, 30) }

    before do
      described_class.call(import, spreadsheet)
      tenant.atua_transport_documents.where(code: first_record[:code])
        .update_all(distance_km: BigDecimal('1300'), original_distance_km: first_record[:distance_km], distance_adjusted_at: adjusted_at)
    end

    it 'keeps the adjusted distance when the document is imported again' do
      described_class.call(import, spreadsheet)

      document = tenant.atua_transport_documents.find_by!(code: first_record[:code])
      expect(document).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: first_record[:distance_km],
                                          distance_adjusted_at: adjusted_at)
    end
  end
end
