require 'rails_helper'

RSpec.describe RevenueProjections::ReplayCommand do
  let(:tenant) { create(:tenant) }
  let(:at) { Time.zone.local(2026, 11, 11, 6) }
  let(:november) { Date.new(2026, 11, 1).all_month }

  def issue_regular_days(plate, cents)
    (Date.new(2026, 8, 17)..Date.new(2026, 11, 10)).each do |date|
      next if date.sunday?

      create(:atua_transport_document, tenant:, plate:, issued_at: date.in_time_zone.change(hour: 10), freight_cents: date.saturday? ? cents / 2 : cents)
    end
  end

  def projection(snapshots, period_type, taken_on)
    snapshots.find { it.period_type == period_type && it.taken_on == taken_on }
  end

  before do
    issue_regular_days('AAA1A11', 100_000)
    travel_to(at)
  end

  context 'with every document of the company' do
    before { RevenueProjections::RefreshMemoryCommand.call(tenant, at:) }

    let(:replay) { described_class.call(tenant, tenant.billable_freights, november, today: at.to_date) }

    it 'rebuilds the same projection of each morning stored in the memory' do
      [Date.new(2026, 10, 1).all_month, november].each do |month|
        replayed_month = described_class.call(tenant, tenant.billable_freights, month, today: at.to_date)
        stored = tenant.revenue_projection_snapshots.where(taken_on: month).order(:taken_on, :period_type).to_a

        expect(stored.size).to eq(month.first.month == 10 ? 62 : 22)
        stored.each do |snapshot|
          replayed = projection(replayed_month.snapshots, snapshot.period_type, snapshot.taken_on)

          expect(replayed.attributes.slice(*%w[period_start period_end reference_at realized_cents projected_cents low_cents high_cents days]))
            .to eq(snapshot.attributes.slice(*%w[period_start period_end reference_at realized_cents projected_cents low_cents high_cents days]))
        end
      end
      expect(RevenueProjection::Snapshot.count).to eq(84)
    end

    it 'rebuilds the same daily totals and the same forecast of today' do
      expect(replay.totals_by_date.keys.minmax).to eq([Date.new(2026, 8, 17), Date.new(2026, 11, 10)])
      tenant.revenue_projection_daily_totals.where(date: Date.new(2026, 8, 17)..).find_each do |total|
        expect(replay.totals_by_date[total.date].attributes.slice('billed_cents', 'documents_count', 'day_type', 'hourly_cents'))
          .to eq(total.attributes.slice('billed_cents', 'documents_count', 'day_type', 'hourly_cents'))
      end
      expect(replay.forecasts_by_date[at.to_date].forecast_cents).to eq(tenant.revenue_projection_day_forecasts.find_by!(date: at.to_date).forecast_cents)
      expect(replay.forecasts_by_date.keys).to eq((Date.new(2026, 11, 1)..Date.new(2026, 11, 11)).to_a)
    end
  end

  context 'with the documents of a single truck' do
    before do
      issue_regular_days('BBB2B22', 50_000)
      RevenueProjections::RefreshMemoryCommand.call(tenant, at:)
    end

    it 'projects only the billing of the documents of the cut' do
      replay = described_class.call(tenant, tenant.billable_freights.by_plate('BBB2B22'), november, today: at.to_date)

      expect(projection(replay.snapshots, 'month', Date.new(2026, 11, 1)).projected_cents).to eq(1_150_000)
      expect(projection(tenant.revenue_projection_snapshots, 'month', Date.new(2026, 11, 1)).projected_cents).to eq(3_450_000)
      expect(projection(replay.snapshots, 'week', Date.new(2026, 11, 8))).to have_attributes(realized_cents: 0, projected_cents: 275_000)
      expect(replay.totals_by_date[Date.new(2026, 11, 10)]).to have_attributes(billed_cents: 50_000, documents_count: 1)
      expect(replay.forecasts_by_date[Date.new(2026, 11, 11)].forecast_cents).to eq(50_000)
    end
  end

  it 'does not count the days before the first document of the company as days without billing' do
    replay = described_class.call(tenant, tenant.billable_freights.by_plate('AAA1A11'), Date.new(2026, 10, 1).all_month, today: at.to_date)

    expect(replay.totals_by_date.keys.min).to eq(Date.new(2026, 8, 17))
    expect(projection(replay.snapshots, 'month', Date.new(2026, 10, 1))).to have_attributes(projected_cents: 2_450_000, low_cents: 2_450_000)
  end

  it 'has nothing to replay for a period that has not started' do
    replay = described_class.call(tenant, tenant.billable_freights, Date.new(2026, 12, 1).all_month, today: at.to_date)

    expect(replay.forecasts_by_date).to eq({})
    expect(replay.snapshots.map(&:taken_on).uniq).to eq([])
  end
end
