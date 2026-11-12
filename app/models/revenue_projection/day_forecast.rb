module RevenueProjection
  class DayForecast < ApplicationRecord
    belongs_to :tenant

    enum :day_type, DailyTotal::DAY_TYPES.index_with(&:to_s), validate: true

    validates :date, :wday, :typical_cents, :factor, :forecast_cents, :low_cents, :high_cents, :forecast_at, presence: true
    validates :date, uniqueness: { scope: :tenant_id }

    scope :with_actual, -> { where.not(actual_cents: nil) }
  end
end
