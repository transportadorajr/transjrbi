module Admin
  class DeviceRegistrationForm < BaseForm
    CODE_FORMAT = /\A[A-Za-z0-9]{4,10}\z/

    attribute :tenant_id, :integer
    attribute :registration_id, :integer
    attribute :code, :string

    attr_reader :registration

    validates :tenant, :pending_registration, presence: true
    validates :code, format: { with: CODE_FORMAT }

    def tenant
      return @tenant if @tenant&.id == tenant_id

      @tenant = Tenant.find_by(id: tenant_id)
    end

    def pending_registration
      @pending_registration ||= tenant&.atua_device_registrations&.find_by(id: registration_id)
    end

    def request_code
      @registration = Atua::RequestDeviceCodeCommand.call(tenant)
    rescue Atua::Error => e
      errors.add(:base, e.message)
      nil
    end

    def submit
      @registration = Atua::ConfirmDeviceCommand.call(pending_registration, code)
    rescue Atua::Error => e
      errors.add(:base, e.message)
    end
  end
end
