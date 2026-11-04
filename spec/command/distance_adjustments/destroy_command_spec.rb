require 'rails_helper'

RSpec.describe DistanceAdjustments::DestroyCommand do
  let!(:tenant) { create(:tenant) }
  let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450')) }
  let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }

  before { DistanceAdjustments::ApplyCommand.call(adjustment) }

  it 'removes the adjustment and gives the document its distance from Atua back' do
    expect { described_class.call(adjustment) }.to change(DistanceAdjustment, :count).by(-1)

    expect(document.reload).to have_attributes(distance_km: BigDecimal('300'), original_distance_km: nil, distance_adjusted_at: nil)
  end
end
