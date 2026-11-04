require 'rails_helper'

RSpec.describe DistanceAdjustments::ApplyPendingCommand do
  let!(:tenant) { create(:tenant) }
  let!(:pending) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450')) }
  let!(:waiting) { create(:distance_adjustment, tenant:, transport_document_number: '74999', distance_km: BigDecimal('610')) }
  let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }

  it 'applies the adjustments whose documents arrived and keeps the others waiting' do
    expect(described_class.call(tenant)).to eq(1)

    expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
    expect(pending.reload.applied_at).to be_present
    expect(waiting.reload.applied_at).to be_nil
  end

  it 'does nothing when it runs again' do
    described_class.call(tenant)

    expect(described_class.call(tenant)).to eq(0)
    expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
  end
end
