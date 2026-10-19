module Admin
  module DeviceRegistrationsHelper
    def admin_device_registration_instructions(form)
      t('admin.device_registrations.modal.instructions', email: form.pending_registration&.masked_email,
                                                         minutes: Atua::DeviceRegistration::CODE_TTL.in_minutes.to_i)
    end

    def admin_device_registration_errors(form)
      return if form.errors.empty?

      content_tag(:div, form.errors.full_messages.to_sentence, class: 'alert alert-danger', role: :alert)
    end

    def admin_tenant_device_badge(tenant)
      return status_badge(t('admin.device_registrations.badge.registered'), kind: :success) if tenant.atua_device_hash.present?

      status_badge(t('admin.device_registrations.badge.missing'), kind: :warning)
    end

    def admin_device_registration_button(tenant)
      button_to admin_tenant_device_registration_path(tenant),
                class: 'btn btn-sm btn-outline-primary btn-round',
                form_class: 'd-inline-block',
                data: { turbo_confirm: t('admin.device_registrations.button.confirm', tenant: tenant.trade_name) } do
        safe_join([icon(:'shield-check', class: 'me-1'), t('admin.device_registrations.button.label')])
      end
    end
  end
end
