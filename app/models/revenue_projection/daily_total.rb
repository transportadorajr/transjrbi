module RevenueProjection
  class DailyTotal < ApplicationRecord
    DAY_TYPES = %i[regular weekday_holiday saturday_holiday bridge_day optional_day month_end].freeze
    HOURS = 24

    belongs_to :tenant

    enum :day_type, DAY_TYPES.index_with(&:to_s), validate: true

    validates :date, :wday, :consolidated_at, presence: true
    validates :date, uniqueness: { scope: :tenant_id }
  end
end
