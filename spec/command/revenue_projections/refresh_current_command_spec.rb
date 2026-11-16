require 'rails_helper'

RSpec.describe RevenueProjections::RefreshCurrentCommand do
  let(:tenant) { create(:tenant) }
  let(:morning) { Time.zone.local(2026, 11, 12, 6) }
  let(:at) { Time.zone.local(2026, 11, 12, 14, 10) }
  let(:synced_at) { Time.zone.local(2026, 11, 12, 13, 30) }

  def issue(time, reais)
    create(:atua_transport_document, tenant:, issued_at: time, freight_cents: reais * 100)
  end

  def snapshot(period_type, taken_on = at.to_date)
    tenant.revenue_projection_snapshots.find_by!(period_type:, taken_on:)
  end

  it 'does nothing before the projection of the morning' do
    expect(described_class.call(tenant, at:)).to eq(0)
  end

  context 'with the projection of the morning and the billing of the day so far' do
    before do
      (Date.new(2026, 8, 17)..Date.new(2026, 11, 11)).each do |date|
        issue(date.in_time_zone.change(hour: 10), date.saturday? ? 500 : 1_000) unless date.sunday?
      end
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: Time.zone.local(2026, 11, 11, 15))
      RevenueProjections::SnapshotCommand.call(tenant, at: morning)
      create(:revenue_projection_snapshot, tenant:, taken_on: Date.new(2026, 11, 11), projected_cents: 2_200_000)
      issue(Time.zone.local(2026, 11, 12, 10), 1_500)
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: synced_at)
    end

    it 'recalculates the projections with the last sync and keeps the projection of the morning' do
      expect { expect(described_class.call(tenant, at:)).to eq(2) }.not_to change(RevenueProjection::Snapshot, :count)

      expect(snapshot('month')).to have_attributes(projected_cents: 2_300_000, current_projected_cents: 2_350_000, current_reference_at: synced_at,
                                                   current_refreshed_at: at)
      expect(snapshot('week')).to have_attributes(projected_cents: 550_000, current_projected_cents: 600_000)
      expect(snapshot('month', Date.new(2026, 11, 11))).to have_attributes(projected_cents: 2_200_000, current_projected_cents: nil)
    end

    it 'gives the same result when it runs again' do
      described_class.call(tenant, at:)
      described_class.call(tenant, at:)

      expect(snapshot('month')).to have_attributes(projected_cents: 2_300_000, current_projected_cents: 2_350_000)
      expect(RevenueProjection::Snapshot.where(tenant:).count).to eq(3)
    end
  end
end
