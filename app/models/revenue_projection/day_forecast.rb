module RevenueProjection
  class DayForecast < ApplicationRecord
    belongs_to :tenant

    enum :day_type, DailyTotal::DAY_TYPES.index_with(&:to_s), validate: true

    validates :date, :wday, :typical_cents, :factor, :forecast_cents, :low_cents, :high_cents, :forecast_at, presence: true
    validates :date, uniqueness: { scope: :tenant_id }

    scope :with_actual, -> { where.not(actual_cents: nil) }
  end
end

# == Schema Information
#
# Table name: revenue_projection_day_forecasts
#
#  id             :bigint           not null, primary key
#  actual_cents   :bigint
#  backfilled     :boolean          default(FALSE), not null
#  date           :date             not null
#  day_type       :enum             default("regular"), not null
#  error_ratio    :decimal(8, 4)
#  factor         :decimal(6, 4)    not null
#  forecast_at    :datetime         not null
#  forecast_cents :bigint           not null
#  high_cents     :bigint           not null
#  low_cents      :bigint           not null
#  typical_cents  :bigint           not null
#  wday           :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_revenue_projection_day_forecasts_on_tenant_id_and_date  (tenant_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
