class PasswordChangeForm < BaseForm
  attribute :password, :string
  attribute :password_confirmation, :string

  attr_accessor :user

  validates :password, presence: true, confirmation: true
  validates :password, length: { within: Devise.password_length }, allow_blank: true
  validate :password_must_differ_from_current

  def submit
    user.update!(password:, password_confirmation:, password_change_required: false)
  end

  private

  def password_must_differ_from_current
    errors.add(:password, :same_as_current) if password.present? && user.valid_password?(password)
  end
end
