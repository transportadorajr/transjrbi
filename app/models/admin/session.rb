module Admin
  class Session < ApplicationRecord
    INACTIVITY_TIMEOUT = 30.minutes

    belongs_to :user, class_name: 'Admin::User'

    has_secure_token :token

    scope :expired, -> { where(last_active_at: ...INACTIVITY_TIMEOUT.ago) }

    before_validation :set_last_active_at, on: :create

    def expired?
      last_active_at < INACTIVITY_TIMEOUT.ago
    end

    def renew
      update!(last_active_at: Time.current)
    end

    private

    def set_last_active_at
      self.last_active_at ||= Time.current
    end
  end
end

# == Schema Information
#
# Table name: admin_sessions
#
#  id             :bigint           not null, primary key
#  ip_address     :string
#  last_active_at :datetime         not null
#  token          :string           not null
#  user_agent     :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_admin_sessions_on_token    (token) UNIQUE
#  index_admin_sessions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => admin_users.id)
#
