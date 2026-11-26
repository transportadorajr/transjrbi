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

  context 'when the drivers carry subcontracted or redispatched CEs without an MDF-e' do
    before do
      create(:atua_transport_document, tenant:, document_kind: 'ce', service_kind: 'Subcontratação', plate: 'BEJ4G50', driver_code: 501,
                                       issued_at: Time.zone.local(2026, 11, 25, 11), arrival_on: Date.new(2026, 11, 27))
      create(:atua_transport_document, tenant:, document_kind: 'ce', service_kind: 'Redespacho', plate: 'SFI0G78', driver_code: 502,
                                       issued_at: Time.zone.local(2026, 11, 20, 11), arrival_on: Date.new(2026, 11, 22))
      create(:atua_transport_document, tenant:, document_kind: 'ce', service_kind: 'Subcontratação', plate: 'SFI0G78', driver_code: 503,
                                       issued_at: Time.zone.local(2026, 11, 24, 11), arrival_on: nil)
      create(:atua_transport_document, tenant:, document_kind: 'ce', service_kind: 'Normal', plate: 'INT6R00', driver_code: 504,
                                       issued_at: Time.zone.local(2026, 11, 24, 11), arrival_on: Date.new(2026, 11, 26))
    end

    it 'counts the days from the issue to the arrival of the CE as trip days' do
      expect(described_class.call(tenant, [501, 502, 503, 504], week)).to eq(
        501 => Set[Date.new(2026, 11, 25), Date.new(2026, 11, 26), Date.new(2026, 11, 27)],
        502 => Set[Date.new(2026, 11, 22)],
        503 => Set[Date.new(2026, 11, 24)],
      )
    end
  end

  it 'returns nothing without drivers' do
    expect(described_class.call(tenant, [], week)).to eq({})
  end
end
