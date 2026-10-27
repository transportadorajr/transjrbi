module Admin
  class TenantForm < CompanyForm
    attribute :owner_name, :string
    attribute :owner_email, :string
    attribute :owner_password, :string
    attribute :owner_password_confirmation, :string

    before_validation :normalize_owner_fields

    validates :owner_name, :owner_email, :owner_password, presence: true, on: :create
    validates :owner_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true, on: :create
    validates :owner_password, length: { within: Devise.password_length }, confirmation: true, allow_blank: true,
                               on: :create
    validate :owner_email_must_be_unique, on: :create

    attr_reader :owner

    def tenant
      @tenant ||= Tenant.new
    end

    def submit
      return super if persisted?

      transaction do
        super
        create_owner
      end
    end

    private

    def create_owner
      @owner = tenant.users.new(name: owner_name, email: owner_email, password: owner_password,
                                password_confirmation: owner_password_confirmation, user_type: :owner, activated: true)
      @owner.skip_confirmation!
      @owner.save!
    end

    def normalize_owner_fields
      self.owner_name = owner_name.to_s.squish
      self.owner_email = owner_email.to_s.strip.downcase
    end

    def owner_email_must_be_unique
      return if owner_email.blank? || !::User.exists?(email: owner_email)

      errors.add(:owner_email, :taken)
    end
  end
end
