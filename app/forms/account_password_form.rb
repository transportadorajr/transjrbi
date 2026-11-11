class AccountPasswordForm < BaseForm
  attribute :current_password, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  attr_accessor :user

  validates :current_password, presence: true
  validates :password, presence: true, confirmation: true
  validates :password, length: { within: Devise.password_length }, allow_blank: true
  validate :current_password_must_match
  validate :password_must_differ_from_current

  def submit
    user.update!(password:, password_confirmation:)
  end

  private

  def current_password_must_match
    errors.add(:current_password, :invalid) if current_password.present? && !user.valid_password?(current_password)
  end

  def password_must_differ_from_current
    errors.add(:password, :same_as_current) if password.present? && user.valid_password?(password)
  end
end
