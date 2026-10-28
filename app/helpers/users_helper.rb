module UsersHelper
  def users_menu(user)
    menus = []

    menus << user_show_menu(user) if can?(:read, user)
    menus << user_edit_menu(user) if can?(:update, user)
    menus << user_confirm_menu(user) if can?(:confirm, user)
    menus << user_deactivation_menu(user) if can?(:deactivate, user)

    menus
  end

  def user_status_badge(user)
    return status_badge(t('users.index.deactivated'), kind: :danger) unless user.activated?
    return status_badge(t('users.index.pending'), kind: :warning) unless user.confirmed?

    status_badge(t('users.index.active'), kind: :success)
  end

  def user_password_form_errors(user_password_form)
    return if user_password_form.errors.empty?

    content_tag(:div, user_password_form.errors.full_messages.to_sentence, class: 'alert alert-danger', role: :alert)
  end

  def user_initial(user)
    user.name.first.upcase
  end

  def user_type_badge(user)
    content_tag :span, user.user_type_name, class: ['badge rounded-pill', user_type_badge_class(user)]
  end

  def user_type_options(user_form)
    return [[User.human_enum_name(:user_type, :owner), 'owner']] if user_form.owner?

    UserForm.enum_options_for_select(:user_type)
  end

  def user_type_prompt(user_form)
    t('helpers.select.prompt') unless user_form.user_type_locked?
  end

  def user_form_url(user_form)
    user_form.persisted? ? user_path(user_form.user) : users_path
  end

  def user_form_submit_label(user_form)
    t("helpers.submit.user.#{user_form.persisted? ? :update : :create}")
  end

  def user_phone(user)
    user.phone.presence || t('users.show.blank')
  end

  def user_activated_at(user)
    user.activated_at ? l(user.activated_at, format: :short) : t('users.show.blank')
  end

  def user_password_change_required(user)
    t(user.password_change_required? ? 'users.show.password_change_pending' : 'users.show.password_change_not_pending')
  end

  def user_edit_button(user)
    return unless can?(:update, user)

    link_to edit_user_path(user), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('users.show.edit')
    end
  end

  def user_create_button
    create_button(t('users.index.new_user')) if can?(:create, User)
  end

  def user_permissions_fields(form, user_form, resources)
    return if user_form.accesses_locked?

    render 'users/permissions_fields', f: form, user_form:, resources:
  end

  def user_password_fields(form, user_form)
    return unless user_form.password_settable?

    render 'users/password_fields', f: form
  end

  def user_permissions_card(user, accesses)
    return if user.owner?

    render 'users/permissions_card', accesses:
  end

  def user_permissions_table(accesses)
    return render('shared/no_content') if accesses.none?

    render 'users/permissions_table', accesses:
  end

  def user_permissions_fields_table(form, user_form, resources)
    return content_tag(:div, render('shared/no_content'), class: 'permissions-card-empty') if resources.none?

    render 'users/permissions_fields_table', f: form, user_form:, resources:
  end

  def resource_access_hint(resource)
    resource.writable? ? t('users.permissions.writable') : t('users.permissions.read_only')
  end

  def access_flag_icon(granted)
    return access_flag_tag(:'check-circle', 'text-success', t('users.permissions.granted')) if granted

    access_flag_tag(:'x-circle', 'text-danger', t('users.permissions.denied'))
  end

  private

  def access_flag_tag(icon_name, color_class, label)
    content_tag :span, class: color_class do
      concat icon(icon_name)
      concat content_tag(:span, label, class: 'visually-hidden')
    end
  end

  def user_type_badge_class(user)
    user.operator? ? 'text-bg-light border' : 'text-bg-primary'
  end

  def user_show_menu(user)
    Menu.new(name: :show, record: user, url: user_path(user), icon: :eye)
  end

  def user_edit_menu(user)
    Menu.new(name: :edit, record: user, url: edit_user_path(user), icon: :pencil)
  end

  def user_confirm_menu(user)
    Menu.new(
      name: :confirm,
      record: user,
      url: confirmation_user_path(user, **request.query_parameters),
      icon: :'patch-check',
      color: :success,
      data: { turbo_stream: true },
    )
  end

  def user_deactivation_menu(user)
    return user_activate_menu(user) unless user.activated?

    user_destroy_menu(user)
  end

  def user_destroy_menu(user)
    Menu.new(
      name: :destroy,
      record: user,
      url: user_path(user, **request.query_parameters),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('users.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end

  def user_activate_menu(user)
    Menu.new(
      name: :activate,
      record: user,
      url: activate_user_path(user, **request.query_parameters),
      icon: :'check-circle',
      data: {
        turbo_confirm: t('users.index.confirm_activate'),
        turbo_method: :patch,
      },
    )
  end
end
