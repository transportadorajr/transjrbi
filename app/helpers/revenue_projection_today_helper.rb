module RevenueProjectionTodayHelper
  TODAY_CARD_COLUMNS = 'col-12 col-md-6 col-xxl-3'.freeze

  def revenue_projection_history_today_cards(today)
    safe_join([
                counter_card(:warning, t('revenue_projection_histories.today.forecast'), revenue_projection_history_money(today.forecast_cents),
                             col_class: TODAY_CARD_COLUMNS),
                counter_card(:primary, t('revenue_projection_histories.today.billed'), revenue_projection_history_money(today.billed_cents),
                             col_class: TODAY_CARD_COLUMNS),
                counter_card(:dark, t('revenue_projection_histories.today.month_projection'),
                             revenue_projection_history_money(today.month_projected_cents), col_class: TODAY_CARD_COLUMNS),
                counter_card(:dark, t('revenue_projection_histories.today.week_projection'),
                             revenue_projection_history_money(today.week_projected_cents), col_class: TODAY_CARD_COLUMNS),
              ])
  end

  def revenue_projection_history_today_progress(today)
    return unless today.achieved_ratio

    render 'revenue_projection_histories/today_progress', today:
  end

  def revenue_projection_history_today_achieved(today)
    t('revenue_projection_histories.today.achieved', ratio: number_to_percentage(today.achieved_ratio * 100, precision: 1))
  end

  def revenue_projection_history_today_remaining(today)
    return t('revenue_projection_histories.today.exceeded', value: revenue_projection_history_money(today.difference_cents)) if today.remaining_cents.zero?

    t('revenue_projection_histories.today.remaining', value: revenue_projection_history_money(today.remaining_cents))
  end

  def revenue_projection_history_today_progress_value(today)
    [today.billed_cents, today.forecast_cents].min
  end

  def revenue_projection_history_today_note(today)
    return t('revenue_projection_histories.today.never_synced') unless today.last_synced_at

    t('revenue_projection_histories.today.note', time: l(today.last_synced_at, format: :date_time))
  end

  def revenue_projection_history_today_refresh_note(today)
    return t('revenue_projection_histories.today.morning_projections') unless today.projections_refreshed_at

    t('revenue_projection_histories.today.refreshed_projections', time: l(today.projections_refreshed_at, format: :hour_minute))
  end
end
