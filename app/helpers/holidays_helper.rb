module HolidaysHelper
  def holidays_menu(holiday)
    menus = []

    menus << holiday_edit_menu(holiday) if can?(:update, :holidays)
    menus << holiday_destroy_menu(holiday) if can?(:destroy, :holidays)

    menus
  end

  def holiday_date(holiday)
    l(holiday.date, format: :with_weekday)
  end

  def holiday_year_options(years)
    options_for_select(years, params[:year].presence || Date.current.year)
  end

  def holiday_scope_type_options
    options_for_select(Holiday.enum_options_for_select(:scope_type), params[:scope_type])
  end

  def holiday_form_url(holiday_form)
    holiday_form.persisted? ? holiday_path(holiday_form.holiday) : holidays_path
  end

  def holiday_form_submit_label(holiday_form)
    t("helpers.submit.holiday.#{holiday_form.persisted? ? :update : :create}")
  end

  def holiday_create_button
    create_button(t('holidays.index.new_holiday')) if can?(:create, :holidays)
  end

  private

  def holiday_edit_menu(holiday)
    Menu.new(name: :edit, record: holiday, url: edit_holiday_path(holiday), icon: :pencil)
  end

  def holiday_destroy_menu(holiday)
    Menu.new(
      name: :destroy,
      record: holiday,
      url: holiday_path(holiday),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('holidays.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
