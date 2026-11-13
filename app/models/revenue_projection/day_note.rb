module RevenueProjection
  class DayNote < ApplicationRecord
    BODY_MAX_LENGTH = 500

    belongs_to :tenant
    belongs_to :user

    validates :date, :body, presence: true
    validates :body, length: { maximum: BODY_MAX_LENGTH }
  end
end

# == Schema Information
#
# Table name: revenue_projection_day_notes
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  date       :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_revenue_projection_day_notes_on_tenant_id_and_date  (tenant_id,date) UNIQUE
#  index_revenue_projection_day_notes_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (user_id => users.id)
#
