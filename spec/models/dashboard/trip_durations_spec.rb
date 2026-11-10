require 'rails_helper'

RSpec.describe Dashboard::TripDurations do
  let!(:tenant) { create(:tenant) }

  def create_trip(code, started_at:, closed_at:, freight_cents:)
    manifest = create(:atua_manifest, tenant:, code:, branch_name: 'JR', trip_started_at: started_at, closed_at:)
    create(:atua_transport_document, tenant:, number: code.to_s, series: 1, branch_name: 'JR', freight_cents:)
    create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: code.to_s, transport_document_series: 1,
                                    branch_name: 'JR')
    manifest
  end

  describe '.for_manifests' do
    subject(:durations) { described_class.for_manifests(tenant.atua_manifests) }

    before do
      create_trip(41_001, started_at: Time.zone.local(2026, 10, 1, 8), closed_at: Time.zone.local(2026, 10, 2, 10), freight_cents: 300_000)
      create_trip(41_002, started_at: Time.zone.local(2026, 10, 1, 8), closed_at: Time.zone.local(2026, 10, 1, 20), freight_cents: 400_000)
      create_trip(41_003, started_at: Time.zone.local(2026, 10, 5, 8), closed_at: nil, freight_cents: 900_000)
      create_trip(41_004, started_at: Time.zone.local(2026, 10, 5, 8), closed_at: Time.zone.local(2026, 10, 5, 8, 20), freight_cents: 900_000)
      create_trip(41_005, started_at: Time.zone.local(2026, 9, 1, 8), closed_at: Time.zone.local(2026, 10, 1, 8), freight_cents: 900_000)
    end

    it 'averages the closed trips weighting the net freight by the hours' do
      expect(durations.measured_count).to eq(2)
      expect(durations.average.hours).to eq(19)
      expect(durations.net_per_hour.format).to eq('R$ 184,21')
    end

    it 'counts the trips in progress and the closed trips left out of the average' do
      expect(durations.in_progress_count).to eq(1)
      expect(durations.excluded_count).to eq(2)
    end
  end

  context 'without measured trips' do
    subject(:durations) { described_class.new([]) }

    it 'has no average and no net per hour' do
      expect(durations.average).to be_nil
      expect(durations.net_per_hour).to be_nil
      expect(durations.measured_count).to eq(0)
    end
  end
end
