require 'rails_helper'

RSpec.describe WorkSchedules::TripDatesCommand do
  let(:tenant) { create(:tenant) }
  let(:week) { Date.new(2026, 11, 22)..Date.new(2026, 11, 28) }

  def create_trip(driver_code, tenant: self.tenant, **attributes)
    manifest = create(:atua_manifest, tenant:, **attributes)
    transport_document = create(:atua_transport_document, tenant:, driver_code:)
    create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
  end

  context 'when the drivers have trips in the week' do
    before do
      create_trip(501, trip_started_at: Time.zone.local(2026, 11, 20, 8), closed_at: Time.zone.local(2026, 11, 23, 18))
      create_trip(502, trip_started_at: nil, departure_on: Date.new(2026, 11, 26), closed_at: Time.zone.local(2026, 11, 27, 9))
      create_trip(503, trip_started_at: Time.zone.local(2026, 11, 10, 8), closed_at: Time.zone.local(2026, 11, 12, 18))
      create_trip(501, tenant: create(:tenant), trip_started_at: Time.zone.local(2026, 11, 25, 8), closed_at: Time.zone.local(2026, 11, 25, 18))
    end

    it 'returns the trip dates of each driver inside the period' do
      expect(described_class.call(tenant, [501, 502, 503], week)).to eq(
        501 => Set[Date.new(2026, 11, 22), Date.new(2026, 11, 23)],
        502 => Set[Date.new(2026, 11, 26), Date.new(2026, 11, 27)],
      )
    end
  end

  context 'when the trip is still in progress' do
    before { create_trip(501, trip_started_at: Time.zone.local(2026, 11, 26, 6), closed_at: nil) }

    it 'counts the days up to today' do
      travel_to Date.new(2026, 11, 27) do
        expect(described_class.call(tenant, 501, week)[501]).to eq(Set[Date.new(2026, 11, 26), Date.new(2026, 11, 27)])
      end
    end
  end

  it 'returns nothing without drivers' do
    expect(described_class.call(tenant, [], week)).to eq({})
  end
end
