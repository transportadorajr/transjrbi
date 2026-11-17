module Activatable
  extend ActiveSupport::Concern

  included do
    attribute :activated_at, :datetime, default: -> { Time.current }

    time_based_flag :activated, scheduled: false

    scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }

    before_create { activated_at_will_change! if activated_at.nil? }
  end
end
