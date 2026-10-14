require 'rails_helper'

RSpec.describe EmptyLegTransportDocument do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:empty_leg) { create(:empty_leg, tenant:) }
  let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_500) }
  let!(:link) { create(:empty_leg_transport_document, empty_leg:, tenant:, transport_document_code: 80_500) }

  before { create(:atua_transport_document, tenant: other_tenant, code: 80_500) }

  it 'links the empty leg to the freight of the same tenant' do
    expect(link.transport_document).to eq(transport_document)
    expect(empty_leg.transport_documents).to eq([transport_document])
    expect(transport_document.empty_legs).to eq([empty_leg])
  end

  it 'links a freight only once to the same empty leg' do
    duplicate = build(:empty_leg_transport_document, empty_leg:, tenant:, transport_document_code: 80_500)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:transport_document_code]).to be_present
  end

  it 'is removed with its empty leg' do
    expect { empty_leg.destroy! }.to change(described_class, :count).by(-1)
  end

  it 'is removed by the database when the empty leg is deleted in bulk' do
    expect { EmptyLeg.where(id: empty_leg.id).delete_all }.to change(described_class, :count).by(-1)
  end
end
