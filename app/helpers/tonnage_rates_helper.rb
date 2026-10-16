module TonnageRatesHelper
  def tonnage_rates_menu(tonnage_rate)
    menus = []

    menus << tonnage_rate_show_menu(tonnage_rate) if can?(:read, :tonnage_rates)
    menus << tonnage_rate_edit_menu(tonnage_rate) if can?(:update, :tonnage_rates)
    menus << tonnage_rate_destroy_menu(tonnage_rate) if can?(:destroy, :tonnage_rates)

    menus
  end

  def tonnage_rate_status_badge(tonnage_rate)
    return status_badge(t('tonnage_rates.index.active'), kind: :success) if tonnage_rate.activated?

    status_badge(t('tonnage_rates.index.deactivated'), kind: :danger)
  end

  def tonnage_rate_origin(tonnage_rate)
    city = tax_city(tonnage_rate.origin_city, tonnage_rate.origin_state)
    return city if tonnage_rate.nickname.blank?

    t('tonnage_rates.origin_with_nickname', origin: city, nickname: tonnage_rate.nickname)
  end

  def tonnage_rate_label(tonnage_rate)
    t('tonnage_rates.label', name: tonnage_rate.name, origin: tonnage_rate_origin(tonnage_rate))
  end

  def tonnage_rate_month(month)
    l(month, format: :month_year)
  end

  def tonnage_rate_per_ton(rate)
    t('tonnage_rates.per_ton', rate: tax_money(rate))
  end

  def tonnage_weight(weight_tons)
    t('tonnage_rates.weight', weight: number_with_precision(weight_tons, precision: 3))
  end

  def tonnage_rate_form_url(tonnage_rate_form)
    tonnage_rate_form.persisted? ? tonnage_rate_path(tonnage_rate_form.tonnage_rate) : tonnage_rates_path
  end

  def tonnage_rate_form_submit_label(tonnage_rate_form)
    t("helpers.submit.tonnage_rate.#{tonnage_rate_form.persisted? ? :update : :create}")
  end

  def tonnage_rate_create_button
    create_button(t('tonnage_rates.index.new_tonnage_rate')) if can?(:create, :tonnage_rates)
  end

  def tonnage_rate_edit_button(tonnage_rate)
    return unless can?(:update, :tonnage_rates)

    link_to edit_tonnage_rate_path(tonnage_rate), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('tonnage_rates.show.edit')
    end
  end

  private

  def tonnage_rate_show_menu(tonnage_rate)
    Menu.new(name: :show, record: tonnage_rate, url: tonnage_rate_path(tonnage_rate), icon: :eye)
  end

  def tonnage_rate_edit_menu(tonnage_rate)
    Menu.new(name: :edit, record: tonnage_rate, url: edit_tonnage_rate_path(tonnage_rate), icon: :pencil)
  end

  def tonnage_rate_destroy_menu(tonnage_rate)
    Menu.new(
      name: :destroy,
      record: tonnage_rate,
      url: tonnage_rate_path(tonnage_rate),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('tonnage_rates.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
