module Dashboard
  class RevenueProjection
    FEATURE = :revenue_projection
    PERIOD_TYPES = %w[week month].freeze
    DEFAULT_PERIOD_TYPE = 'month'.freeze
    LABEL_FORMAT = :chart_week

    class << self
      def enabled?(tenant)
        Flipper.enabled?(FEATURE, tenant)
      end

      def sanitize_period_type(period_type)
        PERIOD_TYPES.include?(period_type.to_s) ? period_type.to_s : DEFAULT_PERIOD_TYPE
      end
    end

    delegate :period_type, :period, :reference_at, :days, :realized, :projected, :low, :high, :upcoming_holidays, :history?, to: :result

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

    def anchor_date
      reference_date == period.last ? reference_date.yesterday : reference_date
    end

    def realized_points
      total = 0

      anchored_days.to_h do |day|
        total += day.realized_cents
        [label(day.date), reais(total)]
      end
    end

    def projected_points
      total = anchored_days.sum(&:realized_cents)
      carried = anchored_days.sum(&:expected_cents)

      { label(anchor_date) => reais(total) }.merge(
        result.days.drop(anchored_days.size).to_h do |day|
          total += day.realized_cents + day.expected_cents + carried
          carried = 0
          [label(day.date), reais(total)]
        end,
      )
    end

    def anchored_days
      @anchored_days ||= result.days.take_while { it.date <= anchor_date }
    end

    def label(date)
      I18n.l(date, format: LABEL_FORMAT)
    end

    def reais(cents)
      Money.from_cents(cents).to_f
    end
  end
end
