module InsuranceRatesHelper
  def insurance_rates_menu(insurance_rate)
    menus = []

    menus << insurance_rate_show_menu(insurance_rate) if can?(:read, :insurance_rates)
    menus << insurance_rate_edit_menu(insurance_rate) if can?(:update, :insurance_rates)
    menus << insurance_rate_destroy_menu(insurance_rate) if can?(:destroy, :insurance_rates)

    menus
  end

  def insurance_rate_status_badge(insurance_rate, current_insurance_rate)
    return status_badge(t('insurance_rates.statuses.current'), kind: :success) if insurance_rate == current_insurance_rate
    return status_badge(t('insurance_rates.statuses.scheduled'), kind: :warning) if insurance_rate.valid_from > Date.current

    status_badge(t('insurance_rates.statuses.expired'), kind: :secondary)
  end

  def insurance_rate_label(insurance_rate)
    t('insurance_rates.label', date: l(insurance_rate.valid_from))
  end

  def insurance_percentage(percentage)
    number_to_percentage(percentage, precision: 4, strip_insignificant_zeros: true)
  end

  def insurance_rate_form_url(insurance_rate_form)
    insurance_rate_form.persisted? ? insurance_rate_path(insurance_rate_form.insurance_rate) : insurance_rates_path
  end

  def insurance_rate_form_submit_label(insurance_rate_form)
    t("helpers.submit.insurance_rate.#{insurance_rate_form.persisted? ? :update : :create}")
  end

  def insurance_rate_create_button
    create_button(t('insurance_rates.index.new_insurance_rate')) if can?(:create, :insurance_rates)
  end

  def insurance_rate_edit_button(insurance_rate)
    return unless can?(:update, :insurance_rates)

    link_to edit_insurance_rate_path(insurance_rate), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('insurance_rates.show.edit')
    end
  end

  private

  def insurance_rate_show_menu(insurance_rate)
    Menu.new(name: :show, record: insurance_rate, url: insurance_rate_path(insurance_rate), icon: :eye)
  end

  def insurance_rate_edit_menu(insurance_rate)
    Menu.new(name: :edit, record: insurance_rate, url: edit_insurance_rate_path(insurance_rate), icon: :pencil)
  end

  def insurance_rate_destroy_menu(insurance_rate)
    Menu.new(
      name: :destroy,
      record: insurance_rate,
      url: insurance_rate_path(insurance_rate),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('insurance_rates.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
