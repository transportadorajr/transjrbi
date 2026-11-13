require 'rails_helper'

RSpec.describe Dashboard::RevenueProjectionHistory do
  let(:tenant) { create(:tenant) }
  let(:today) { Date.new(2026, 11, 4) }

  def snapshot(taken_on, projected_cents, period_type: 'month', **)
    period = period_type == 'month' ? taken_on.all_month : taken_on.all_week(:sunday)
    create(:revenue_projection_snapshot, tenant:, period_type:, period_start: period.first, period_end: period.last, taken_on:,
                                         reference_at: taken_on.in_time_zone.change(hour: 5), projected_cents:, low_cents: projected_cents,
                                         high_cents: projected_cents, **)
  end

  def total(date, billed_cents, documents_count: 1, day_type: 'regular')
    create(:revenue_projection_daily_total, tenant:, date:, billed_cents:, documents_count:, day_type:)
  end

  def forecast(date, forecast_cents, day_type: 'regular')
    create(:revenue_projection_day_forecast, tenant:, date:, forecast_cents:, day_type:)
  end

  it 'has nothing to show without snapshots' do
    expect(described_class.new(tenant, 'month', Date.new(2026, 11, 1).all_month, today:)).not_to be_any
  end

  context 'with the current month in progress' do
    before do
      snapshot(Date.new(2026, 10, 1), 2_000_000)
      snapshot(Date.new(2026, 11, 1), 2_300_000, reconstructed: true)
      snapshot(Date.new(2026, 11, 2), 2_310_000, reconstructed: true)
      snapshot(Date.new(2026, 11, 4), 2_330_000)
      snapshot(Date.new(2026, 11, 1), 0, period_type: 'week', days: [
                 { date: '2026-11-01', realized_cents: 0, expected_cents: 0 }, { date: '2026-11-02', realized_cents: 0, expected_cents: 30_000 },
                 { date: '2026-11-03', realized_cents: 0, expected_cents: 100_000 }, { date: '2026-11-07', realized_cents: 0, expected_cents: 50_000 }
               ])
      total(Date.new(2026, 11, 1), 0, documents_count: 0)
      total(Date.new(2026, 11, 2), 40_000, documents_count: 2, day_type: 'weekday_holiday')
      total(Date.new(2026, 11, 3), 120_000, documents_count: 5)
      forecast(Date.new(2026, 11, 1), 0)
      forecast(Date.new(2026, 11, 2), 30_000, day_type: 'weekday_holiday')
      forecast(Date.new(2026, 11, 3), 100_000)
      forecast(Date.new(2026, 11, 4), 100_000)
    end

    let(:history) { described_class.new(tenant, 'month', Date.new(2026, 11, 1).all_month, today:) }

    it 'lists the months with snapshots' do
      expect(history).to be_month
      expect(history).to be_snapshot_period
      expect(history.start).to eq(Date.new(2026, 11, 1))
      expect(history.starts).to eq([Date.new(2026, 11, 1), Date.new(2026, 10, 1)])
    end

    it 'follows the projection of the week the same way' do
      week = described_class.new(tenant, 'week', Date.new(2026, 11, 1)..Date.new(2026, 11, 7), today:)

      expect(week).to be_week
      expect(week.starts).to eq([Date.new(2026, 11, 1)])
      expect(week.period).to eq(Date.new(2026, 11, 1)..Date.new(2026, 11, 7))
      expect(week.opening.projected_cents).to eq(0)
      expect(week.billed_cents).to eq(160_000)
      expect(week.day_rows.map { [it.date.day, it.projected_cents] }).to eq([[1, 0], [2, nil], [3, nil]])
      expect(week.week_rows).to eq([])
      expect(week.chart_data.first[:name]).to eq('Projeção da semana')
    end

    it 'compares the daily forecasts with the billing of any other range of days' do
      range = described_class.new(tenant, 'range', Date.new(2026, 11, 2)..Date.new(2026, 11, 3), today:)

      expect(range).to be_any
      expect(range).not_to be_snapshot_period
      expect(range.snapshots).to eq([])
      expect(range).to be_closed
      expect(range.forecast_cents).to eq(130_000)
      expect(range.billed_cents).to eq(160_000)
      expect(range.difference_cents).to eq(30_000)
      expect(range.difference_ratio.round(3)).to eq(0.231)
      expect(range.day_rows.map { [it.date.day, it.projected_cents] }).to eq([[2, 2_310_000], [3, nil]])
      expect(range.week_rows.map(&:period)).to eq([Date.new(2026, 11, 2)..Date.new(2026, 11, 3)])
      expect(range.chart_data).to eq(
        [{ name: 'Previsto acumulado', data: { '02/11' => 300.0, '03/11' => 1_300.0 } },
         { name: 'Faturado acumulado', data: { '02/11' => 400.0, '03/11' => 1_600.0 } }],
      )
    end

    it 'compares the latest projection with the opening one while the month is open' do
      expect(history).not_to be_closed
      expect(history.last_closed_date).to eq(Date.new(2026, 11, 3))
      expect(history.opening.taken_on).to eq(Date.new(2026, 11, 1))
      expect(history.latest.taken_on).to eq(Date.new(2026, 11, 4))
      expect(history.billed_cents).to eq(160_000)
      expect(history.difference_cents).to eq(30_000)
      expect(history.hit_since).to be_nil
      expect(history.reconstructed_period).to eq(Date.new(2026, 11, 1)..Date.new(2026, 11, 2))
    end

    it 'compares the forecast of each closed day with its billing' do
      expect(history.day_rows.map { [it.date.day, it.day_type, it.forecast_cents, it.billed_cents, it.documents_count, it.projected_cents] })
        .to eq([[1, 'regular', 0, 0, 0, 2_300_000], [2, 'weekday_holiday', 30_000, 40_000, 2, 2_310_000], [3, 'regular', 100_000, 120_000, 5, nil]])
      expect(history.day_rows.map(&:difference_cents)).to eq([0, 10_000, 20_000])
      expect(history.day_rows.map { it.difference_ratio&.round(3) }).to eq([nil, 0.333, 0.2])
    end

    it 'compares the opening projection of the started weeks with their billing' do
      expect(history.week_rows.map(&:to_h)).to eq(
        [{ period: Date.new(2026, 11, 1)..Date.new(2026, 11, 7), opening_cents: 180_000, forecast_cents: 130_000, billed_cents: 160_000, closed: false }],
      )
      expect(history.week_rows.first.difference_cents).to be_nil
    end

    it 'charts the projection of each morning with the billing accumulated until then' do
      expect(history.chart_data.map { it[:name] }).to eq(['Projeção do mês', 'Mínimo provável', 'Máximo provável', 'Faturado acumulado'])
      expect(history.chart_data.first[:data]).to eq('01/11' => 23_000.0, '02/11' => 23_100.0, '04/11' => 23_300.0)
      expect(history.chart_data.last[:data]).to eq('01/11' => 0.0, '02/11' => 400.0)
    end
  end

  context 'with a closed month' do
    before do
      snapshot(Date.new(2026, 10, 1), 2_000_000)
      snapshot(Date.new(2026, 10, 15), 2_150_000)
      snapshot(Date.new(2026, 10, 31), 2_190_000)
      total(Date.new(2026, 10, 10), 2_200_000)
    end

    let(:history) { described_class.new(tenant, 'month', Date.new(2026, 10, 1).all_month, today:) }

    it 'compares the billing of the month with the opening projection and tells since when the projection hit it' do
      expect(history).to be_closed
      expect(history.billed_cents).to eq(2_200_000)
      expect(history.difference_cents).to eq(200_000)
      expect(history.difference_ratio).to eq(0.1)
      expect(history.hit_since).to eq(Date.new(2026, 10, 15))
      expect(history.reconstructed_period).to be_nil
      expect(history.chart_data.last).to eq(name: 'Faturado no mês', data: { '01/10' => 22_000.0, '15/10' => 22_000.0, '31/10' => 22_000.0 })
    end

    it 'accumulates the billing until the end of each day so the last day matches the billing of the month' do
      realized = history.chart_data.find { it[:name] == 'Faturado acumulado' }

      expect(realized[:data]).to eq('01/10' => 0.0, '15/10' => 22_000.0, '31/10' => 22_000.0)
      expect(realized[:data].values.last).to eq(Money.from_cents(history.billed_cents).to_f)
    end

    it 'cuts the weeks at the limits of the month' do
      expect(history.week_rows.map(&:period)).to eq([Date.new(2026, 10, 1)..Date.new(2026, 10, 3), Date.new(2026, 10, 4)..Date.new(2026, 10, 10),
                                                     Date.new(2026, 10, 11)..Date.new(2026, 10, 17), Date.new(2026, 10, 18)..Date.new(2026, 10, 24),
                                                     Date.new(2026, 10, 25)..Date.new(2026, 10, 31)])
      expect(history.week_rows.map { [it.closed, it.billed_cents, it.opening_cents] }.second).to eq([true, 2_200_000, nil])
    end
  end
end
