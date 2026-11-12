require 'rails_helper'

RSpec.describe Dashboard::RevenueProjection do
  let(:holiday) { build(:holiday, date: Date.new(2026, 11, 13)) }
  let(:days) do
    [
      RevenueProjection::Day.new(date: Date.new(2026, 11, 11), realized_cents: 100_000, expected_cents: 50_000, low_cents: 40_000,
                                 high_cents: 60_000, holiday: nil),
      RevenueProjection::Day.new(date: Date.new(2026, 11, 12), realized_cents: 0, expected_cents: 200_000, low_cents: 150_000,
                                 high_cents: 250_000, holiday: nil),
      RevenueProjection::Day.new(date: Date.new(2026, 11, 13), realized_cents: 0, expected_cents: 30_000, low_cents: 20_000,
                                 high_cents: 40_000, holiday:),
    ]
  end
  let(:result) do
    RevenueProjection::Result.new(period_type: :week, period: Date.new(2026, 11, 11)..Date.new(2026, 11, 13),
                                  reference_at: Time.zone.local(2026, 11, 11, 15), days:, factors: {}, history_days: 84)
  end
  let(:projection) { described_class.new(result) }

  describe '#chart_data' do
    it 'starts the projection at the realized point of today so the lines join' do
      expect(projection.chart_data).to eq(
        [
          { name: 'Faturado', data: { '11/11' => 1_000.0 } },
          { name: 'Projeção', data: { '11/11' => 1_000.0, '12/11' => 3_500.0, '13/11' => 3_800.0 } },
        ],
      )
    end

    context 'when today is the last day of the period' do
      let(:result) do
        RevenueProjection::Result.new(period_type: :week, period: Date.new(2026, 11, 11)..Date.new(2026, 11, 13),
                                      reference_at: Time.zone.local(2026, 11, 13, 15), days: last_days, factors: {}, history_days: 84)
      end
      let(:last_days) do
        [
          RevenueProjection::Day.new(date: Date.new(2026, 11, 11), realized_cents: 100_000, expected_cents: 0, low_cents: 0,
                                     high_cents: 0, holiday: nil),
          RevenueProjection::Day.new(date: Date.new(2026, 11, 12), realized_cents: 200_000, expected_cents: 0, low_cents: 0,
                                     high_cents: 0, holiday: nil),
          RevenueProjection::Day.new(date: Date.new(2026, 11, 13), realized_cents: 50_000, expected_cents: 40_000, low_cents: 30_000,
                                     high_cents: 50_000, holiday: nil),
        ]
      end

      it 'ends the realized line yesterday and joins it to the projected close of today' do
        expect(projection.chart_data).to eq(
          [
            { name: 'Faturado', data: { '11/11' => 1_000.0, '12/11' => 3_000.0 } },
            { name: 'Projeção', data: { '12/11' => 3_000.0, '13/11' => 3_900.0 } },
          ],
        )
        expect(projection.projected).to eq(Money.from_cents(390_000))
      end
    end
  end

  describe 'totals' do
    it 'delegates the totals and the holidays to the result' do
      expect(projection.realized).to eq(Money.from_cents(100_000))
      expect(projection.projected).to eq(Money.from_cents(380_000))
      expect(projection.low).to eq(Money.from_cents(310_000))
      expect(projection.high).to eq(Money.from_cents(450_000))
      expect(projection.upcoming_holidays).to eq([holiday])
      expect(projection.reference_date).to eq(Date.new(2026, 11, 11))
    end
  end

  describe '.sanitize_period_type' do
    it 'keeps a known period and falls back to the month' do
      expect(described_class.sanitize_period_type('week')).to eq('week')
      expect(described_class.sanitize_period_type('year')).to eq('month')
      expect(described_class.sanitize_period_type(nil)).to eq('month')
    end
  end

  describe '.enabled?' do
    let(:tenant) { create(:tenant) }

    it 'follows the feature flag of the tenant' do
      expect(described_class.enabled?(tenant)).to be(false)

      Flipper.enable_actor(:revenue_projection, tenant)

      expect(described_class.enabled?(tenant)).to be(true)
    end
  end
end
