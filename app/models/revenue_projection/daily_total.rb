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

# == Schema Information
#
# Table name: revenue_projection_daily_totals
#
#  id              :bigint           not null, primary key
#  billed_cents    :bigint           default(0), not null
#  consolidated_at :datetime         not null
#  date            :date             not null
#  day_type        :enum             default("regular"), not null
#  documents_count :integer          default(0), not null
#  hourly_cents    :bigint           default([]), not null, is an Array
#  wday            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tenant_id       :bigint           not null
#
# Indexes
#
#  index_revenue_projection_daily_totals_on_tenant_id_and_date  (tenant_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
