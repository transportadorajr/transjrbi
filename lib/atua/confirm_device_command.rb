module Atua
  class ConfirmDeviceCommand
    class << self
      def call(registration, code, client: nil)
        new(registration, code, client:).call
      end
    end

    def initialize(registration, code, client: nil)
      @registration = registration
      @code = code
      @client = client
    end

    def call
      return registration if registration.confirmed?
      raise DeviceVerificationError, I18n.t('atua.errors.device_code_expired') unless registration.code_sent? && !registration.expired?

      device = client.confirm_device(registration.session, code)

      DeviceRegistration.transaction do
        registration.tenant.update!(atua_device_hash: device.device_hash, atua_device_token: device.device_cookie || registration.tenant.atua_device_token)
        registration.confirm!
      end

      registration
    end

    private

    attr_reader :registration, :code

    def client
      @client ||= Client.new(Configuration.for(registration.tenant), retries: false)
    end
  end
end
