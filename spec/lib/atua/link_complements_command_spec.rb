require 'rails_helper'

RSpec.describe Atua::LinkComplementsCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with a value complement of a normal transport document' do
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991') }
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_number: '67991')
    end
    let!(:other_tenant_original) { create(:atua_transport_document, tenant: other_tenant, number: '67991') }

    it 'links the complement to the transport document it complements' do
      expect(described_class.call(tenant)).to eq(1)

      expect(complement.reload.complemented_transport_document).to eq(original)
      expect(original.reload.value_complements).to contain_exactly(complement)
      expect(other_tenant_original.reload.value_complements).to be_empty
    end

    it 'does not touch the complement again when nothing changed' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to(change { complement.reload.updated_at })
    end
  end

  context 'when the complemented number exists in another series and branch' do
    let!(:other_series) { create(:atua_transport_document, tenant:, number: '67991', series: 2) }
    let!(:other_branch) { create(:atua_transport_document, tenant:, number: '67991', branch_name: 'JR FOZ') }
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991') }
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_number: '67991')
    end

    it 'links the complement to the document of its own series and branch' do
      described_class.call(tenant)

      expect(complement.reload.complemented_transport_document).to eq(original)
    end
  end

  context 'when the complemented transport document was canceled' do
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991', canceled_at: Time.current) }
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_number: '67991',
                                       complemented_transport_document: original)
    end

    it 'unlinks the complement' do
      described_class.call(tenant)

      expect(complement.reload.complemented_transport_document).to be_nil
    end
  end

  context 'when the complemented transport document was not imported' do
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_number: '60000')
    end

    it 'leaves the complement unlinked' do
      expect(described_class.call(tenant)).to eq(0)

      expect(complement.reload.complemented_transport_document).to be_nil
    end
  end

  context 'when a linked document is no longer a value complement' do
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991') }
    let!(:document) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: 'Normal', complemented_number: '67991',
                                       complemented_transport_document: original)
    end

    it 'unlinks the document' do
      described_class.call(tenant)

      expect(document.reload.complemented_transport_document).to be_nil
    end
  end
end
