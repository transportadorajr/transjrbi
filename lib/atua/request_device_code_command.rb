module Atua
  class RequestDeviceCodeCommand
    class << self
      def call(tenant, production_access: false, client: nil)
        new(tenant, production_access:, client:).call
      end
    end

    def initialize(tenant, production_access: false, client: nil)
      @tenant = tenant
      @production_access = production_access
      @client = client
    end

    def call
      state = client.request_device_code
      return if state.nil?

      tenant.atua_device_registrations.code_sent.update_all(status_type: :failed, session_state: nil, updated_at: Time.current)
      tenant.atua_device_registrations.create!(
        status_type: :code_sent, masked_email: state.fetch('masked_email'), session_state: state.to_json,
        expires_at: DeviceRegistration::CODE_TTL.from_now
      )
    end

    private

    attr_reader :tenant, :production_access

    def client
      @client ||= Client.new(Configuration.for(tenant, production_access:), retries: false)
    end
  end
end
