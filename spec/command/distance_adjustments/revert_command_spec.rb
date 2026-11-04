require 'rails_helper'

RSpec.describe DistanceAdjustments::RevertCommand do
  let!(:tenant) { create(:tenant) }
  let!(:adjusted) do
    create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'),
                                     distance_adjusted_at: 1.day.ago)
  end
  let!(:other) { create(:atua_transport_document, tenant:, number: '74121', distance_km: BigDecimal('380')) }

  it 'gives the documents their distance from Atua back' do
    expect(described_class.call(tenant, '74120')).to eq(1)

    expect(adjusted.reload).to have_attributes(distance_km: BigDecimal('300'), original_distance_km: nil, distance_adjusted_at: nil)
    expect(other.reload).to have_attributes(distance_km: BigDecimal('380'), distance_adjusted_at: nil)
  end

  it 'does nothing when it runs again' do
    described_class.call(tenant, '74120')

    expect(described_class.call(tenant, '74120')).to eq(0)
    expect(adjusted.reload.distance_km).to eq(BigDecimal('300'))
  end
end
