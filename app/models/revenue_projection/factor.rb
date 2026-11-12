module RevenueProjection
  class Factor < ApplicationRecord
    FACTOR_TYPES = %i[weekday_holiday saturday_holiday bridge_day optional_day month_end weekday_bias].freeze
    DEFAULTS = { weekday_holiday: 0.30, saturday_holiday: 0.80, bridge_day: 0.60, optional_day: 0.50, month_end: 1.0, weekday_bias: 1.0 }.freeze
    LIMITS = {
      weekday_holiday: 0.0..1.0, saturday_holiday: 0.0..1.0, bridge_day: 0.0..1.0, optional_day: 0.0..1.0, month_end: 0.5..2.0,
      weekday_bias: 0.8..1.25
    }.freeze
    MIN_OBSERVATIONS = { weekday_holiday: 2, saturday_holiday: 2, bridge_day: 2, optional_day: 2, month_end: 6, weekday_bias: 4 }.freeze

    belongs_to :tenant

    enum :factor_type, FACTOR_TYPES.index_with(&:to_s), validate: true

    validates :value, :learned_at, presence: true
    validates :wday, presence: true, if: :weekday_bias?
  end
end
