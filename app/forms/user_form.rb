class UserForm < BaseForm
  PHONE_DIGITS = (10..11)

  attribute :name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :user_type, :string

  enum :user_type, %i[admin operator]

  attr_accessor :user, :editor

  before_validation :normalize_fields

  validates :name, :email, :user_type, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :user_type, inclusion: { in: user_types.keys }, allow_blank: true, unless: :user_type_locked?
  validate :email_must_be_unique, unless: :persisted?
  validate :phone_must_have_valid_digits

  class << self
    def for_user(user, editor:)
      new(name: user.name, email: user.email, phone: user.phone, user_type: user.user_type, user:, editor:)
    end
  end

  def persisted?
    user.present? && user.persisted?
  end

  def id
    user&.id
  end

  def owner?
    persisted? && user.owner?
  end

  def user_type_locked?
    owner? || (persisted? && editor&.operator?)
  end

  def submit
    if persisted?
      update_user
    else
      create_user
    end
  end

  private

  def create_user
    transaction do
      password = SecureRandom.hex(32)

      @user = editor.tenant.users.new(name:, email:, phone:, user_type:, activated: true, password:, password_confirmation: password)
      @user.save!
    end
  end

  def update_user
    attributes = { name:, phone: }
    attributes[:user_type] = user_type unless user_type_locked?

    user.update!(attributes)
  end

  def normalize_fields
    self.name = name&.squish
    self.email = email&.strip&.downcase
    self.phone = phone&.strip.presence
  end

  def email_must_be_unique
    return if email.blank?
    return unless User.exists?(email:)

    errors.add(:email, :taken)
  end

  def phone_must_have_valid_digits
    return if phone.blank?
    return if PHONE_DIGITS.cover?(phone.gsub(/\D/, '').size)

    errors.add(:phone, :invalid)
  end
end
