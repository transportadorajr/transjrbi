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
      expect(history.last_synced_at).to eq(today.in_time_zone.change(hour: 14))
    end
  end
end
