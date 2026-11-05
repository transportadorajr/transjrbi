require 'rails_helper'

RSpec.describe Atua::DiscardManifestsBeforeCutoffCommand do
  let!(:tenant) { create(:tenant) }

  def access_key(number, month: '2603', series: 1)
    format('41%<month>s1021283800010057%<series>03d%<number>09d1266098980', month:, series:, number: number.to_i)
  end

  def create_manifest(numbers, notes:, **attributes)
    manifest = create(:atua_manifest, tenant:, issued_on: Date.new(2026, 4, 3), notes:, **attributes)
    numbers.each do |number|
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                      branch_name: 'JR TRANSPORTES')
    end
    manifest
  end

  context 'when every transport document of the manifest was issued before the cutoff and none was imported' do
    let!(:manifest) { create_manifest(%w[68570 68571], notes: "CT-e #{access_key('68570')}\nCT-e #{access_key('68571')}") }
    let!(:other_tenant_manifest) do
      other_tenant = create(:tenant)
      other = create(:atua_manifest, tenant: other_tenant, code: manifest.code, notes: manifest.notes)
      create(:atua_manifest_document, tenant: other_tenant, manifest_code: other.code, transport_document_number: '68570', transport_document_series: 1)
      other
    end

    it 'removes the manifest and its documents' do
      expect(described_class.call(tenant)).to eq(1)

      expect(manifest.reload.removed_from_atua_at).to be_present
      expect(tenant.atua_manifest_documents.active.where(manifest_code: manifest.code)).to be_empty
      expect(other_tenant_manifest.reload.removed_from_atua_at).to be_nil
    end

    it 'schedules the empty legs calculation' do
      expect { described_class.call(tenant) }.to have_enqueued_job(EmptyLegs::CalculateJob)
    end

    it 'removes nothing when called again' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'when one of the transport documents was issued from the cutoff on' do
    let!(:manifest) { create_manifest(%w[68895 68933], notes: "CT-e #{access_key('68895')}\nCT-e #{access_key('68933', month: '2604')}") }

    it 'keeps the manifest' do
      expect(described_class.call(tenant)).to eq(0)
      expect(manifest.reload.removed_from_atua_at).to be_nil
    end
  end

  context 'when the manifest is linked to an imported transport document' do
    let!(:manifest) { create_manifest(%w[68895 68933], notes: "CT-e #{access_key('68895')}\nCT-e #{access_key('68933')}") }

    before { create(:atua_transport_document, tenant:, number: '68933', series: 1, branch_name: 'JR TRANSPORTES') }

    it 'keeps the manifest' do
      expect(described_class.call(tenant)).to eq(0)
      expect(manifest.reload.removed_from_atua_at).to be_nil
    end
  end

  context 'when the access key of a transport document is not in the notes' do
    let!(:manifest) { create_manifest(%w[68570 68571], notes: "CT-e #{access_key('68570')}") }

    it 'keeps the manifest' do
      expect(described_class.call(tenant)).to eq(0)
      expect(manifest.reload.removed_from_atua_at).to be_nil
    end
  end

  context 'when the transport document was issued in the month of the cutoff but never imported' do
    let!(:manifest) { create_manifest(%w[69674], notes: "CT-e #{access_key('69674', month: '2604')}") }

    it 'keeps the manifest' do
      expect(described_class.call(tenant)).to eq(0)
      expect(manifest.reload.removed_from_atua_at).to be_nil
    end
  end
end
