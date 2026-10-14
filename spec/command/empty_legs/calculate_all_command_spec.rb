require 'rails_helper'

RSpec.describe EmptyLegs::CalculateAllCommand do
  let(:client) { instance_double(Tomtom::Client) }
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:september_trip) { create(:atua_manifest, tenant:, code: 41_100, issued_on: Date.new(2026, 9, 28), trip_started_at: Time.zone.local(2026, 9, 28)) }
  let!(:first_october_trip) { create(:atua_manifest, tenant:, code: 41_200, issued_on: Date.new(2026, 10, 2), trip_started_at: Time.zone.local(2026, 10, 2)) }
  let!(:second_october_trip) { create(:atua_manifest, tenant:, code: 41_300, issued_on: Date.new(2026, 10, 6), trip_started_at: Time.zone.local(2026, 10, 6)) }
  let!(:other_tenant_leg) { create(:empty_leg, tenant: other_tenant, next_manifest_code: 99_999) }

  before { allow(client).to receive(:geocode).and_return([]) }

  it 'calculates the leg of every trip of the tenant' do
    legs = described_class.call(tenant, client:)

    expect(legs.map { |leg| [leg.previous_manifest_code, leg.next_manifest_code] }).to contain_exactly([41_100, 41_200], [41_200, 41_300])
    expect(EmptyLeg.where(tenant:).count).to eq(2)
  end

  it 'reaches back to the trip of the previous month when calculating from a start date' do
    legs = described_class.call(tenant, start_date: '2026-10-01', client:)

    expect(legs.map(&:next_manifest_code)).to contain_exactly(41_200, 41_300)
    expect(legs.find { |leg| leg.next_manifest_code == 41_200 }.previous_manifest_code).to eq(41_100)
  end

  context 'when a trip with a leg is canceled' do
    let!(:stale_leg) { create(:empty_leg, tenant:, previous_manifest_code: 41_100, next_manifest_code: 41_200) }

    before { first_october_trip.update!(status: 'Cancelado') }

    it 'removes its leg and links the next trip to the previous valid one' do
      described_class.call(tenant, start_date: '2026-10-01', client:)

      expect(EmptyLeg.exists?(stale_leg.id)).to be(false)
      expect(EmptyLeg.where(tenant:).pluck(:previous_manifest_code, :next_manifest_code)).to eq([[41_100, 41_300]])
      expect(EmptyLeg.exists?(other_tenant_leg.id)).to be(true)
    end
  end
end
