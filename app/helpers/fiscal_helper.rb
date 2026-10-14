module FiscalHelper
  def fiscal_value(value)
    value.presence || t('fiscal.blank')
  end

  def fiscal_money(money)
    return t('fiscal.blank') unless money

    number_to_currency(money.to_d)
  end

  def fiscal_date(date)
    date ? l(date) : t('fiscal.blank')
  end

  def fiscal_time(time)
    time ? l(time, format: :date_time) : t('fiscal.blank')
  end

  def fiscal_decimal(value, precision: 2)
    value ? number_with_precision(value, precision:) : t('fiscal.blank')
  end

  def fiscal_city(city, state)
    return t('fiscal.blank') if city.blank?
    return city if state.blank?

    t('fiscal.city', city:, state:)
  end

  def fiscal_list(values)
    values.compact_blank.join(', ').presence || t('fiscal.blank')
  end

  def fiscal_situation_badge(record)
    return status_badge(t('fiscal.situations.canceled'), kind: :danger) if record.canceled?

    status_badge(t('fiscal.situations.valid'), kind: :success)
  end
end
