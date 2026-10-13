class UserForm < BaseForm
  PHONE_DIGITS = (10..11)

  attribute :name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :user_type, :string
  attribute :access_attributes, default: -> { [] }

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

  def accesses_locked?
    owner? || editor.nil? || editor.operator?
  end

  def access_for(resource)
    submitted = submitted_accesses.find { |attrs| attrs[:resource_id].to_s == resource.id.to_s }
    return build_access(resource, submitted) if submitted

    user&.accesses&.find { |access| access.resource_id == resource.id } || Access.new(resource:)
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
      persist_accesses
    end
  end

  def update_user
    attributes = { name:, phone: }
    attributes[:user_type] = user_type unless user_type_locked?

    transaction do
      user.update!(attributes)
      persist_accesses
    end
  end

  def persist_accesses
    return if accesses_locked?

    submitted_accesses.each do |attrs|
      resource = Resource.find_by(id: attrs[:resource_id])
      next if resource.nil?

      persist_access(build_access(resource, attrs))
    end
  end

  def persist_access(submitted)
    access = user.accesses.find_or_initialize_by(resource: submitted.resource)

    if submitted.reads? || submitted.creates?
      access.update!(tenant: user.tenant, reads: true, creates: submitted.creates?)
    elsif access.persisted?
      access.destroy!
    end
  end

  def build_access(resource, attrs)
    creates = resource.writable? && boolean(attrs[:creates])

    Access.new(resource:, reads: boolean(attrs[:reads]) || creates, creates:)
  end

  def submitted_accesses
    rows = access_attributes.respond_to?(:values) ? access_attributes.values : Array(access_attributes)

    rows.map { |row| row.to_h.symbolize_keys }
  end

  def boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
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
