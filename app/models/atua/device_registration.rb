module Atua
  class DeviceRegistration < ApplicationRecord
    CODE_TTL = 10.minutes
    STATUSES = %i[code_sent confirmed failed].freeze

    belongs_to :tenant

    encrypts :session_state

    enum :status_type, STATUSES.index_with(&:to_s), validate: true

    validates :expires_at, presence: true

    scope :pending, -> { code_sent.where(expires_at: Time.current..) }

    def expired?
      code_sent? && expires_at < Time.current
    end

    def session
      JSON.parse(session_state.presence || '{}')
    end

    def confirm!
      update!(status_type: :confirmed, confirmed_at: Time.current, session_state: nil, error_message: nil)
    end

    def fail!(message)
      update!(status_type: :failed, session_state: nil, error_message: message)
    end
  end
end

# == Schema Information
#
# Table name: atua_device_registrations
#
#  id            :bigint           not null, primary key
#  confirmed_at  :datetime
#  error_message :text
#  expires_at    :datetime         not null
#  masked_email  :string
#  session_state :text
#  status_type   :enum             default("code_sent"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_atua_device_registrations_on_tenant_id  (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
