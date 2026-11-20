require 'rails_helper'

RSpec.describe Dashboard::RevenueProjectionToday do
  let(:tenant) { create(:tenant) }
  let(:today) { Date.new(2026, 11, 4) }

  before { travel_to(today.in_time_zone.change(hour: 15)) }

  it 'has nothing to show before the forecast of the day' do
    expect(described_class.new(tenant, today:)).not_to be_any
  end

  context 'with the forecast and the snapshots of the morning' do
    before do
      create(:revenue_projection_day_forecast, tenant:, date: today, forecast_cents: 100_000, day_type: 'month_end')
      create(:revenue_projection_snapshot, tenant:, period_type: 'month', period_start: today.beginning_of_month, period_end: today.end_of_month,
                                           taken_on: today, projected_cents: 2_330_000)
      create(:revenue_projection_snapshot, tenant:, period_type: 'week', period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 7),
                                           taken_on: today, projected_cents: 550_000)
      create(:atua_transport_document, tenant:, issued_at: today.in_time_zone.change(hour: 9), freight_cents: 70_000)
      create(:atua_transport_document, tenant:, issued_at: today.in_time_zone.change(hour: 11), freight_cents: 50_000)
      create(:atua_transport_document, tenant:, issued_at: (today - 1).in_time_zone.change(hour: 11), freight_cents: 90_000)
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: today.in_time_zone.change(hour: 14))
    end

    let(:history) { described_class.new(tenant, today:) }

    it 'compares the forecast of the day with the billing so far and shows the projections taken in the morning' do
      expect(history).to be_any
      expect(history).to have_attributes(forecast_cents: 100_000, day_type: 'month_end', billed_cents: 120_000, documents_count: 2,
                                         difference_cents: 20_000, difference_ratio: 0.2)
      expect(history.month_snapshot.projected_cents).to eq(2_330_000)
      expect(history.week_snapshot.projected_cents).to eq(550_000)
      expect(history).to have_attributes(month_projected_cents: 2_330_000, week_projected_cents: 550_000, projections_refreshed_at: nil)
      expect(history.last_synced_at).to eq(today.in_time_zone.change(hour: 14))
    end

    it 'compares the billing of the month and the projection of today with a goal' do
      row = history.goal_row(build(:revenue_goal, tenant:, month: today.beginning_of_month, amount_cents: 2_500_000))

      expect(history.month_billed_cents).to eq(210_000)
      expect(row).to have_attributes(label: 'Transportadora', goal_cents: 2_500_000, realized_cents: 210_000, projected_cents: 2_330_000,
                                     missing_cents: 2_290_000, status: :attention)
      expect(history.goal_row(nil)).to be_nil
    end

    it 'bills the month in the local time zone, leaving out the evening of the last day of the previous month' do
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 31, 22), freight_cents: 40_000)
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 30, 22), freight_cents: 30_000)

      expect(history.month_billed_cents).to eq(240_000)
    end

    it 'shows the projections recalculated during the day' do
      history.month_snapshot.update!(current_projected_cents: 2_400_000, current_refreshed_at: today.in_time_zone.change(hour: 14, min: 10))

      expect(described_class.new(tenant, today:)).to have_attributes(month_projected_cents: 2_400_000, week_projected_cents: 550_000,
                                                                     projections_refreshed_at: today.in_time_zone.change(hour: 14, min: 10))
    end

    it 'tells that the forecast of the day was exceeded with nothing left to bill' do
      expect(history).to have_attributes(achieved_ratio: 1.2, remaining_cents: 0)
    end
  end

  context 'with part of the forecast of the day billed' do
    before do
      create(:revenue_projection_day_forecast, tenant:, date: today, forecast_cents: 28_738_314)
      create(:atua_transport_document, tenant:, issued_at: today.in_time_zone.change(hour: 9), freight_cents: 22_385_256)
    end

    it 'tells how much of the forecast was reached and how much is left' do
      history = described_class.new(tenant, today:)

      expect(history.achieved_ratio.round(3)).to eq(0.779)
      expect(history.remaining_cents).to eq(6_353_058)
    end
  end

  it 'has no progress without a forecast of the day' do
    expect(described_class.new(tenant, today:)).to have_attributes(achieved_ratio: nil, remaining_cents: nil)
  end
end
