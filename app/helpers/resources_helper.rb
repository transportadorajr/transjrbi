module ResourcesHelper
  def resources_menu(resource)
    menus = []

    menus << resource_edit_menu(resource) if can?(:update, resource)
    menus << resource_destroy_menu(resource) if can?(:destroy, resource)

    menus
  end

  def resource_writable_badge(resource)
    return status_badge(t('resources.index.writable'), kind: :success) if resource.writable?

    status_badge(t('resources.index.read_only'), kind: :secondary)
  end

  def resource_form_url(resource_form)
    resource_form.persisted? ? resource_path(resource_form.resource) : resources_path
  end

  def resource_form_submit_label(resource_form)
    t("helpers.submit.resource.#{resource_form.persisted? ? :update : :create}")
  end

  def resource_create_button
    create_button(t('resources.index.new_resource')) if can?(:create, Resource)
  end

  private

  def resource_edit_menu(resource)
    Menu.new(name: :edit, record: resource, url: edit_resource_path(resource), icon: :pencil)
  end

  def resource_destroy_menu(resource)
    Menu.new(
      name: :destroy,
      record: resource,
      url: resource_path(resource),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('resources.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
