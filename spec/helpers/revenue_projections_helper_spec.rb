require 'rails_helper'

RSpec.describe RevenueProjectionsHelper do
  def day(date, realized_cents, expected_cents)
    RevenueProjection::Day.new(date:, realized_cents:, expected_cents:, low_cents: expected_cents, high_cents: expected_cents, holiday: nil)
  end

  let(:projection) do
    days = [day(Date.new(2026, 11, 8), 0, 0), day(Date.new(2026, 11, 9), 100_000, 0), day(Date.new(2026, 11, 10), 50_000, 30_000),
            day(Date.new(2026, 11, 11), 0, 100_000), day(Date.new(2026, 11, 12), 0, 100_000)]
    result = RevenueProjection::Result.new(period_type: :week, period: Date.new(2026, 11, 8)..Date.new(2026, 11, 12),
                                           reference_at: Time.zone.local(2026, 11, 10, 15), days:, factors: {}, history_days: 84)

    Dashboard::RevenueProjection.new(result)
  end

  describe '#revenue_projection_compact_series' do
    it 'labels only the realized billing of today and the projection of the last day on the whole date axis' do
      realized, projected = helper.revenue_projection_compact_series(projection)

      expect(realized[:data].keys).to eq(%w[08/11 09/11 10/11])
      expect(realized.dig(:dataset, :datalabels, :display)).to eq([false, false, true, false, false])
      expect(realized.dig(:dataset, :pointRadius)).to eq([0, 0, 4, 0, 0])
      expect(projected[:data].keys).to eq(%w[10/11 11/11 12/11])
      expect(projected.dig(:dataset, :datalabels, :display)).to eq([false, false, false, false, true])
      expect(projected.dig(:dataset, :pointRadius)).to eq([0, 0, 0, 0, 4])
    end
  end

  describe '#revenue_projection_period_link_class' do
    it 'highlights the selected period' do
      expect(helper.revenue_projection_period_link_class('week', 'week')).to eq('btn btn-sm btn-primary')
      expect(helper.revenue_projection_period_link_class('month', 'week')).to eq('btn btn-sm btn-outline-secondary')
    end
  end

  describe 'memory labels' do
    it 'names the days and the factors of the memory' do
      expect(helper.revenue_projection_day_label(:regular, 1)).to eq('Segunda-feira')
      expect(helper.revenue_projection_day_label(:month_end, nil)).to eq('Fim de mês')
      expect(helper.revenue_projection_factor_label(:weekday_bias, 3)).to eq('Correção de quarta-feira')
      expect(helper.revenue_projection_factor_label(:bridge_day, nil)).to eq('Emenda')
      expect(helper.revenue_projection_factor_value(1.12)).to eq('112% do típico')
    end

    it 'formats the error and the bias' do
      expect(helper.revenue_projection_error(0.0237)).to eq('2,4%')
      expect(helper.revenue_projection_signed_error(0.05)).to eq('+5,0%')
      expect(helper.revenue_projection_signed_error(-0.05)).to eq('-5,0%')
      expect(helper.revenue_projection_bias(-0.029)).to eq('2,9% abaixo do real')
      expect(helper.revenue_projection_bias(0.0001)).to eq('Sem tendência')
    end
  end
end
