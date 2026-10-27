module Admin
  module TenantsHelper
    def admin_tenant_menu(tenant)
      [admin_tenant_edit_menu(tenant)]
    end

    def admin_tenant_owner(tenant)
      tenant.owner&.email || t('admin.tenants.index.blank')
    end

    def admin_tenant_owner_fields(form)
      render('admin/tenants/owner_fields', f: form) unless form.object.persisted?
    end

    def admin_tenant_form_url(tenant_form)
      tenant_form.persisted? ? admin_tenant_path(tenant_form.tenant) : admin_tenants_path
    end

    def admin_tenant_form_submit_label(tenant_form)
      t("helpers.submit.admin_tenant.#{tenant_form.persisted? ? :update : :create}")
    end

    private

    def admin_tenant_edit_menu(tenant)
      Menu.new(name: :edit, record: tenant, url: edit_admin_tenant_path(tenant), icon: :pencil)
    end
  end
end
