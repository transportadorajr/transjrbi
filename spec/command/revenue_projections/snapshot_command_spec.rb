require 'rails_helper'

RSpec.describe RevenueProjections::SnapshotCommand do
  let(:tenant) { create(:tenant) }
  let(:at) { Time.zone.local(2026, 11, 12, 6) }
  let(:synced_at) { Time.zone.local(2026, 11, 11, 15) }

  def issue(time, reais)
    create(:atua_transport_document, tenant:, issued_at: time, freight_cents: reais * 100)
  end

  def snapshot(period_type, taken_on = at.to_date)
    tenant.revenue_projection_snapshots.find_by!(period_type:, taken_on:)
  end

  context 'with twelve weeks of regular billing' do
    before do
      (Date.new(2026, 8, 17)..Date.new(2026, 11, 11)).each do |date|
        issue(date.in_time_zone.change(hour: 10), date.saturday? ? 500 : 1_000) unless date.sunday?
      end
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: synced_at)
    end

    it 'stores the projection of the month and of the week as it stood at the last sync' do
      expect { described_class.call(tenant, at:) }.to change(RevenueProjection::Snapshot, :count).by(2)

      expect(snapshot('month')).to have_attributes(period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 30), reference_at: synced_at,
                                                   realized_cents: 850_000, projected_cents: 2_300_000, low_cents: 2_300_000,
                                                   high_cents: 2_300_000, reconstructed: false)
      week = snapshot('week')
      expect(week).to have_attributes(period_start: Date.new(2026, 11, 8), period_end: Date.new(2026, 11, 14), realized_cents: 300_000,
                                      projected_cents: 550_000)
      expect(week.days.map { it.values_at('date', 'realized_cents', 'expected_cents') })
        .to eq([['2026-11-08', 0, 0], ['2026-11-09', 100_000, 0], ['2026-11-10', 100_000, 0], ['2026-11-11', 100_000, 0],
                ['2026-11-12', 0, 100_000], ['2026-11-13', 0, 100_000], ['2026-11-14', 0, 50_000]])
    end

    it 'ignores a sync finished after the moment of the snapshot' do
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: at + 1.hour)

      described_class.call(tenant, at:)

      expect(snapshot('month').reference_at).to eq(synced_at)
    end

    it 'updates the snapshot of the day when taken again' do
      described_class.call(tenant, at:)
      issue(synced_at.change(hour: 18), 2_000)
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: synced_at.change(hour: 19))

      expect { described_class.call(tenant, at:) }.not_to change(RevenueProjection::Snapshot, :count)

      expect(snapshot('month')).to have_attributes(realized_cents: 1_050_000, reference_at: synced_at.change(hour: 19))
    end

    context 'when the memory has already learned a weekday bias' do
      before { create(:revenue_projection_factor, tenant:, factor_type: 'weekday_bias', wday: 1, value: 1.1, learned: true) }

      it 'applies the current factors to the snapshot of today' do
        described_class.call(tenant, at:)

        expect(snapshot('month').projected_cents).to eq(2_330_000)
      end

      it 'reconstructs a past day with the factors learned until then and keeps the current factors' do
        described_class.call(tenant, at:, reconstructed: true)

        expect(snapshot('month')).to have_attributes(projected_cents: 2_300_000, reconstructed: true)
        expect(tenant.revenue_projection_factors.find_by!(factor_type: 'weekday_bias', wday: 1).value).to eq(BigDecimal('1.1'))
      end
    end

    it 'keeps a snapshot already taken when reconstructing the same day' do
      described_class.call(tenant, at:)

      expect { described_class.call(tenant, at:, reconstructed: true) }.not_to change(RevenueProjection::Snapshot, :count)

      expect(tenant.revenue_projection_snapshots.pluck(:reconstructed)).to eq([false, false])
    end
  end
end
