module TaxHelper
  def tax_value(value)
    value.presence || t('tax.blank')
  end

  def tax_money(money)
    return t('tax.blank') unless money

    number_to_currency(money.to_d)
  end

  def tax_date(date)
    date ? l(date) : t('tax.blank')
  end

  def tax_time(time)
    time ? l(time, format: :date_time) : t('tax.blank')
  end

  def tax_decimal(value, precision: 2)
    value ? number_with_precision(value, precision:) : t('tax.blank')
  end

  def tax_city(city, state)
    return t('tax.blank') if city.blank?
    return city if state.blank?

    t('tax.city', city:, state:)
  end

  def tax_list(values)
    values.compact_blank.join(', ').presence || t('tax.blank')
  end

  def tax_situation_badge(record)
    return status_badge(t('tax.situations.canceled'), kind: :danger) if record.canceled?

    status_badge(t('tax.situations.valid'), kind: :success)
  end
end
