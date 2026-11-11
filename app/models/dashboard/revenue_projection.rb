module Dashboard
  class RevenueProjection
    FEATURE = :revenue_projection
    LABEL_FORMAT = :chart_week

    class << self
      def enabled?(tenant)
        Flipper.enabled?(FEATURE, tenant)
      end
    end

    delegate :period_type, :period, :reference_at, :realized, :projected, :low, :high, :upcoming_holidays, :history?, to: :result

    def initialize(result)
      @result = result
    end

    def reference_date
      reference_at.to_date
    end

    def chart_data
      [
        { name: I18n.t('dashboards.revenue_projection.realized'), data: realized_points },
        { name: I18n.t('dashboards.revenue_projection.projected'), data: projected_points },
      ]
    end

    private

    attr_reader :result

    def realized_points
      total = 0

      result.days.take_while { it.date <= reference_date }.to_h do |day|
        total += day.realized_cents
        [label(day.date), reais(total)]
      end
    end

    def projected_points
      total = result.realized_cents

      result.days.drop_while { it.date < reference_date }.to_h do |day|
        total += day.expected_cents
        [label(day.date), reais(total)]
      end
    end

    def label(date)
      I18n.l(date, format: LABEL_FORMAT)
    end

    def reais(cents)
      Money.from_cents(cents).to_f
    end
  end
end
