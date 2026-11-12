require 'rails_helper'

RSpec.describe RevenueProjections::ConsolidateDaysCommand do
  let(:tenant) { create(:tenant) }
  let(:dates) { Date.new(2026, 10, 30)..Date.new(2026, 11, 2) }

  before do
    create(:holiday, tenant:, date: Date.new(2026, 11, 2), name: 'Finados')
    create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 30, 8, 10), freight_cents: 100_000)
    create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 30, 14, 30), freight_cents: 50_000)
    create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 2, 9), freight_cents: 30_000)
    create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 30, 9), freight_cents: 900_000, canceled_at: Time.current)
    create(:atua_transport_document, issued_at: Time.zone.local(2026, 10, 30, 9), freight_cents: 900_000)
  end

  it 'stores the billing of every day with its hours, weekday and day type' do
    expect(described_class.call(tenant, dates)).to eq(4)

    totals = tenant.revenue_projection_daily_totals.order(:date)
    expect(totals.map { [it.date.day, it.wday, it.day_type, it.billed_cents, it.documents_count] })
      .to eq([[30, 5, 'month_end', 150_000, 2], [31, 6, 'month_end', 0, 0], [1, 0, 'regular', 0, 0], [2, 1, 'weekday_holiday', 30_000, 1]])
    expect(totals.first.hourly_cents.each_with_index.select { |cents, _hour| cents.positive? }).to eq([[100_000, 8], [50_000, 14]])
  end

  it 'updates the days already consolidated and fills the actual billing of their forecasts' do
    described_class.call(tenant, dates)
    forecast = create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 10, 30), forecast_cents: 165_000)
    create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 30, 18), freight_cents: 50_000)

    expect { described_class.call(tenant, dates) }.not_to change(RevenueProjection::DailyTotal, :count)

    expect(tenant.revenue_projection_daily_totals.find_by!(date: Date.new(2026, 10, 30)).billed_cents).to eq(200_000)
    expect(forecast.reload).to have_attributes(actual_cents: 200_000, error_ratio: BigDecimal('-0.175'), day_type: 'month_end')
  end
end
