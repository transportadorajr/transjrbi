require 'rails_helper'

RSpec.describe RevenueProjection::Replay do
  def snapshot(period_type, period, taken_on)
    RevenueProjection::Snapshot.new(period_type:, period_start: period.first, period_end: period.last, taken_on:)
  end

  let(:replay) do
    described_class.new(
      totals_by_date: { Date.new(2026, 10, 30) => :october, Date.new(2026, 11, 2) => :november },
      forecasts_by_date: { Date.new(2026, 11, 3) => :forecast },
      snapshots: [snapshot('month', Date.new(2026, 11, 1).all_month, Date.new(2026, 11, 2)), snapshot('month', Date.new(2026, 11, 1).all_month, Date.new(2026, 11, 1)),
                  snapshot('week', Date.new(2026, 11, 1)..Date.new(2026, 11, 7), Date.new(2026, 11, 1)),
                  snapshot('week', Date.new(2026, 10, 25)..Date.new(2026, 10, 31), Date.new(2026, 10, 25))],
    )
  end

  it 'reads the replayed memory the same way as the stored one' do
    expect(replay.snapshots_of(:month, Date.new(2026, 11, 1)).map(&:taken_on)).to eq([Date.new(2026, 11, 1), Date.new(2026, 11, 2)])
    expect(replay.snapshots_taken(:week, Date.new(2026, 10, 25)..Date.new(2026, 10, 31)).map(&:period_start)).to eq([Date.new(2026, 10, 25)])
    expect(replay.week_snapshots_within(Date.new(2026, 11, 1).all_month).map(&:period_start)).to eq([Date.new(2026, 11, 1)])
    expect(replay.totals(Date.new(2026, 11, 1).all_month)).to eq(Date.new(2026, 11, 2) => :november)
    expect(replay.forecasts(Date.new(2026, 11, 1).all_month)).to eq(Date.new(2026, 11, 3) => :forecast)
    expect(replay).to be_recalculated
  end
end
