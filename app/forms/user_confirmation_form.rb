class UserConfirmationForm < BaseForm
  attribute :confirmation_token, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  validate :confirmation_must_be_pending
  validates :password, presence: true, confirmation: true
  validates :password, length: { within: Devise.password_length }, allow_blank: true

  def user
    return @user if defined?(@user)

    @user = confirmation_token.present? ? User.find_by(confirmation_token:) : nil
  end

  def pending?
    user.present? && user.pending_account_confirmation?
  end

  def submit
    user.assign_attributes(password:, password_confirmation:)

    errors.merge!(user.errors) unless user.confirm
  end

  private

  def confirmation_must_be_pending
    errors.add(:base, :invalid_confirmation_link) unless pending?
  end
end
