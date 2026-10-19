module Admin
  class DeviceRegistrationsController < BaseController
    before_action :set_tenant

    def create
      @device_registration_form = Admin::DeviceRegistrationForm.new(tenant_id: @tenant.id)
      registration = @device_registration_form.request_code

      if registration
        @device_registration_form.registration_id = registration.id
      elsif @device_registration_form.errors.any?
        redirect_to admin_imports_path, alert: @device_registration_form.errors.full_messages.to_sentence
      else
        redirect_to admin_imports_path, notice: t('.already_trusted', tenant: @tenant.trade_name)
      end
    end

    def update
      @device_registration_form = Admin::DeviceRegistrationForm.new(tenant_id: @tenant.id, **device_registration_params)

      if @device_registration_form.save
        redirect_to admin_imports_path, notice: t('.success', tenant: @tenant.trade_name)
      else
        render status: :unprocessable_content
      end
    end

    private

    def set_tenant
      @tenant = Tenant.find(params.expect(:tenant_id))
    end

    def device_registration_params
      params.expect(admin_device_registration: %i[registration_id code]).to_h.symbolize_keys
    end
  end
end
