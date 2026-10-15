module Admin
  module ResourcesHelper
    def admin_resource_menu(resource)
      [admin_resource_edit_menu(resource), admin_resource_destroy_menu(resource)]
    end

    def admin_resource_writable_badge(resource)
      return status_badge(t('admin.resources.index.writable'), kind: :success) if resource.writable?

      status_badge(t('admin.resources.index.read_only'), kind: :secondary)
    end

    def admin_resource_form_url(resource_form)
      resource_form.persisted? ? admin_resource_path(resource_form.resource) : admin_resources_path
    end

    def admin_resource_form_submit_label(resource_form)
      t("helpers.submit.admin_resource.#{resource_form.persisted? ? :update : :create}")
    end

    private

    def admin_resource_edit_menu(resource)
      Menu.new(name: :edit, record: resource, url: edit_admin_resource_path(resource), icon: :pencil)
    end

    def admin_resource_destroy_menu(resource)
      Menu.new(
        name: :destroy,
        record: resource,
        url: admin_resource_path(resource),
        icon: :'x-circle',
        data: {
          turbo_confirm: t('admin.resources.index.confirm_destroy'),
          turbo_method: :delete,
        },
      )
    end
  end
end
