module Admin
  class User < ApplicationRecord
    has_secure_password

    has_many :sessions, class_name: 'Admin::Session', dependent: :destroy

    normalizes :email, with: ->(email) { email.to_s.strip.downcase }

    validates :name, presence: true
    validates :email, presence: true, uniqueness: true

    def authenticate(unencrypted_password)
      super
    rescue BCrypt::Errors::InvalidHash
      false
    end
  end
end

# == Schema Information
#
# Table name: admin_users
#
#  id              :bigint           not null, primary key
#  email           :string           not null
#  name            :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_admin_users_on_email  (email) UNIQUE
#
