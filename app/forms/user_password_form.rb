class UserPasswordForm < BaseForm
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :password_change_required, :boolean, default: true

  attr_accessor :user

  validates :password, presence: true, confirmation: true
  validates :password, length: { within: Devise.password_length }, allow_blank: true
  validate :user_must_be_pending

  def submit
    user.skip_confirmation!
    user.update!(password:, password_confirmation:, password_change_required:, confirmation_token: nil)
  end

  private

  def user_must_be_pending
    errors.add(:base, :already_confirmed) if user.confirmed?
  end
end
