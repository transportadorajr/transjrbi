require 'rails_helper'

RSpec.describe RevenueProjections::RefreshMemoryCommand do
  let(:tenant) { create(:tenant) }
  let(:at) { Time.zone.local(2026, 11, 11, 6) }

  def issue_regular_days(from, to)
    (from..to).each do |date|
      next if date.sunday?

      create(:atua_transport_document, tenant:, issued_at: date.in_time_zone.change(hour: 10), freight_cents: date.saturday? ? 50_000 : 100_000)
    end
  end

  context 'with history and an empty memory' do
    before { issue_regular_days(Date.new(2026, 8, 17), Date.new(2026, 11, 10)) }

    it 'consolidates the history, rebuilds the past forecasts, learns the factors and forecasts today' do
      described_class.call(tenant, at:)

      expect(tenant.revenue_projection_daily_totals.count).to eq(86)
      past = tenant.revenue_projection_day_forecasts.where(date: ...at.to_date)
      expect(past.count).to eq(58)
      expect(past.pluck(:backfilled).uniq).to eq([true])
      expect(past.with_actual.count).to eq(58)
      expect(tenant.revenue_projection_day_forecasts.find_by!(date: at.to_date)).to have_attributes(backfilled: false, forecast_cents: 100_000,
                                                                                                    actual_cents: nil)
      expect(tenant.revenue_projection_factors.count).to eq(12)
      expect(tenant.revenue_projection_factors.find_by!(factor_type: 'weekday_bias', wday: 3)).to have_attributes(value: 1, learned: true)
    end

    it 'does not duplicate the memory when run again on the same day' do
      described_class.call(tenant, at:)

      expect { described_class.call(tenant, at:) }
        .to not_change(RevenueProjection::DailyTotal, :count).and not_change(RevenueProjection::DayForecast, :count)
    end

    it 'reclassifies the days when a holiday is registered later' do
      described_class.call(tenant, at:)
      create(:holiday, tenant:, date: Date.new(2026, 10, 12), name: 'Nossa Senhora Aparecida')

      described_class.call(tenant, at: at + 1.day)

      expect(tenant.revenue_projection_daily_totals.find_by!(date: Date.new(2026, 10, 12)).day_type).to eq('weekday_holiday')
      expect(tenant.revenue_projection_day_forecasts.find_by!(date: Date.new(2026, 10, 12)).day_type).to eq('weekday_holiday')
    end
  end

  it 'does nothing for a tenant without documents' do
    expect { described_class.call(tenant, at:) }.not_to change(RevenueProjection::DailyTotal, :count)
  end
end
