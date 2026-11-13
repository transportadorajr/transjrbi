module RevenueProjectionTodayHelper
  TODAY_CARD_COLUMNS = 'col-12 col-md-6 col-xxl-3'.freeze

  def revenue_projection_history_today_cards(today)
    safe_join([
                counter_card(:warning, t('revenue_projection_histories.today.forecast'), revenue_projection_history_money(today.forecast_cents),
                             col_class: TODAY_CARD_COLUMNS),
                counter_card(:primary, t('revenue_projection_histories.today.billed'), revenue_projection_history_money(today.billed_cents),
                             col_class: TODAY_CARD_COLUMNS),
                counter_card(:dark, t('revenue_projection_histories.today.month_projection'),
                             revenue_projection_history_money(today.month_snapshot&.projected_cents), col_class: TODAY_CARD_COLUMNS),
                counter_card(:dark, t('revenue_projection_histories.today.week_projection'),
                             revenue_projection_history_money(today.week_snapshot&.projected_cents), col_class: TODAY_CARD_COLUMNS),
              ])
  end

  def revenue_projection_history_today_note(today)
    return t('revenue_projection_histories.today.never_synced') unless today.last_synced_at

    t('revenue_projection_histories.today.note', time: l(today.last_synced_at, format: :date_time))
  end
end
