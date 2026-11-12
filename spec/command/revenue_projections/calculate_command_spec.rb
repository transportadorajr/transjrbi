require 'rails_helper'

RSpec.describe RevenueProjections::CalculateCommand do
  let(:tenant) { create(:tenant) }
  let(:wednesday) { Time.zone.local(2026, 11, 11, 15) }

  def issue(time, reais, **)
    create(:atua_transport_document, tenant:, issued_at: time, freight_cents: reais * 100, **)
  end

  def issue_regular_days(from, to, hour: 10)
    (from..to).each do |date|
      next if date.sunday?

      issue(date.in_time_zone.change(hour:), date.saturday? ? 500 : 1_000)
    end
  end

  def sync_at(time)
    create(:atua_import, tenant:, status_type: 'succeeded', finished_at: time)
  end

  context 'with twelve weeks of regular billing' do
    before do
      issue_regular_days(Date.new(2026, 8, 17), Date.new(2026, 11, 11))
      sync_at(wednesday)
    end

    it 'projects the end of the month from the typical billing of each weekday' do
      result = described_class.call(tenant, period_type: :month, at: wednesday)

      expect(result.period).to eq(Date.new(2026, 11, 1)..Date.new(2026, 11, 30))
      expect(result.reference_at).to eq(wednesday)
      expect(result.realized).to eq(Money.from_cents(850_000))
      expect(result.projected).to eq(Money.from_cents(2_300_000))
      expect(result.low).to eq(result.projected)
      expect(result.high).to eq(result.projected)
      expect(result.history_days).to eq(75)
      expect(result).to be_history
    end

    it 'consolidates the days missing in the memory before projecting' do
      expect { described_class.call(tenant, period_type: :month, at: wednesday) }.to change(RevenueProjection::DailyTotal, :count).by(86)

      expect(tenant.revenue_projection_daily_totals.maximum(:date)).to eq(Date.new(2026, 11, 10))
      expect(tenant.revenue_projection_daily_totals.find_by!(date: Date.new(2026, 10, 30))).to have_attributes(billed_cents: 100_000, day_type: 'month_end')
    end

    it 'raises the last days of the month with the month end factor learned in the memory' do
      create(:revenue_projection_factor, tenant:, factor_type: 'month_end', value: 1.2, learned: true)

      result = described_class.call(tenant, period_type: :month, at: wednesday)

      expect(result.projected).to eq(Money.from_cents(2_350_000))
    end

    it 'corrects each weekday with the bias learned in the memory' do
      create(:revenue_projection_factor, tenant:, factor_type: 'weekday_bias', wday: 1, value: 1.1, learned: true)

      result = described_class.call(tenant, period_type: :month, at: wednesday)

      expect(result.projected).to eq(Money.from_cents(2_330_000))
    end

    it 'projects the end of the week from sunday to saturday' do
      result = described_class.call(tenant, period_type: :week, at: wednesday)

      expect(result.period).to eq(Date.new(2026, 11, 8)..Date.new(2026, 11, 14))
      expect(result.realized).to eq(Money.from_cents(300_000))
      expect(result.projected).to eq(Money.from_cents(550_000))
      expect(result.days.map { [it.date.day, it.realized_cents, it.expected_cents] })
        .to eq([[8, 0, 0], [9, 100_000, 0], [10, 100_000, 0], [11, 100_000, 0], [12, 0, 100_000], [13, 0, 100_000], [14, 0, 50_000]])
    end

    context 'with a holiday ahead in the month' do
      let!(:black_consciousness) { create(:holiday, tenant:) }

      it 'reduces the projection of the holiday with the default factor' do
        result = described_class.call(tenant, period_type: :month, at: wednesday)

        expect(result.projected).to eq(Money.from_cents(2_230_000))
        expect(result.upcoming_holidays).to eq([black_consciousness])
        expect(result.factors.fetch(:weekday_holiday)).to eq(0.30)
      end

      context 'when the memory learned the factor of the past holidays' do
        before do
          [Date.new(2026, 10, 12), Date.new(2026, 11, 2)].each do |date|
            tenant.atua_transport_documents.where(issued_at: date.all_day).update_all(freight_cents: 40_000)
            create(:holiday, tenant:, date:, name: 'Feriado')
          end
          create(:revenue_projection_factor, tenant:, factor_type: 'weekday_holiday', value: 0.4, observations_count: 2, learned: true)
        end

        it 'applies the learned factor and keeps the holidays out of the typical billing' do
          result = described_class.call(tenant, period_type: :month, at: wednesday)

          expect(result.factors.fetch(:weekday_holiday)).to eq(0.40)
          expect(result.realized).to eq(Money.from_cents(790_000))
          expect(result.projected).to eq(Money.from_cents(2_180_000))
          expect(result.history_days).to eq(73)
        end
      end
    end

    it 'counts only the billing shown on the freight billing dashboard' do
      excluded_issuer = create(:excluded_issuer, tenant:, code: 77, name: 'ROBO')
      issue(wednesday.change(hour: 9), 9_000, canceled_at: wednesday)
      issue(wednesday.change(hour: 9), 9_000, removed_from_atua_at: wednesday)
      issue(wednesday.change(hour: 9), 9_000, vehicle_sale: true)
      issue(wednesday.change(hour: 9), 9_000, issuer_code: excluded_issuer.code)
      issue(wednesday.change(hour: 9), 9_000, tenant: create(:tenant))

      result = described_class.call(tenant, period_type: :week, at: wednesday)

      expect(result.realized).to eq(Money.from_cents(300_000))
      expect(result.projected).to eq(Money.from_cents(550_000))
    end
  end

  context 'with the billing split along the day' do
    before do
      (Date.new(2026, 10, 19)..Date.new(2026, 11, 10)).each do |date|
        next if date.sunday? || date.saturday?

        issue(date.in_time_zone.change(hour: 8), 500)
        issue(date.in_time_zone.change(hour: 14), 500)
      end
      issue(wednesday.change(hour: 8), 500)
      issue(wednesday.change(hour: 14), 500)
    end

    it 'projects the rest of the current day from the share usually billed until the last sync' do
      sync_at(wednesday.change(hour: 12))

      result = described_class.call(tenant, period_type: :week, at: wednesday)
      today = result.days.find { it.date == wednesday.to_date }

      expect(result.reference_at).to eq(wednesday.change(hour: 12))
      expect(today.realized_cents).to eq(50_000)
      expect(today.expected_cents).to eq(50_000)
      expect(result.projected).to eq(Money.from_cents(500_000))
    end

    it 'uses the current time when the tenant never synced' do
      result = described_class.call(tenant, period_type: :week, at: wednesday)

      expect(result.reference_at).to eq(wednesday)
      expect(result.realized).to eq(Money.from_cents(300_000))
      expect(result.projected).to eq(Money.from_cents(500_000))
    end

    it 'starts the period at its first day when the last sync is older' do
      sync_at(Time.zone.local(2026, 10, 20, 9))

      result = described_class.call(tenant, period_type: :week, at: wednesday)

      expect(result.reference_at).to eq(Time.zone.local(2026, 11, 8))
      expect(result.realized).to eq(Money.from_cents(0))
      expect(result.projected).to eq(Money.from_cents(500_000))
    end
  end

  context 'without history' do
    before { issue(wednesday.change(hour: 9), 1_000) }

    it 'projects only the realized billing' do
      result = described_class.call(tenant, period_type: :month, at: wednesday)

      expect(result.realized).to eq(Money.from_cents(100_000))
      expect(result.projected).to eq(result.realized)
      expect(result).not_to be_history
    end
  end

  it 'rejects an unknown period type' do
    expect { described_class.call(tenant, period_type: :year) }.to raise_error(ArgumentError, 'unknown period type: year')
  end
end
