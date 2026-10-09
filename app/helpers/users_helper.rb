module UsersHelper
  def users_menu(user)
    menus = []

    menus << user_show_menu(user) if can?(:read, user)
    menus << user_edit_menu(user) if can?(:update, user)

    menus
  end

  def user_status_badge(user)
    return status_badge(t('users.index.active'), kind: :success) if user.activated?

    status_badge(t('users.index.deactivated'), kind: :danger)
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

  private

  def user_type_badge_class(user)
    user.operator? ? 'text-bg-light border' : 'text-bg-primary'
  end

  def user_show_menu(user)
    Menu.new(name: :show, record: user, url: user_path(user), icon: :eye)
  end

  def user_edit_menu(user)
    Menu.new(name: :edit, record: user, url: edit_user_path(user), icon: :pencil)
  end
end
