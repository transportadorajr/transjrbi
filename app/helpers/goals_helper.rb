module GoalsHelper
  GOAL_CARD_COLUMNS = 'col-6 col-xl-4'.freeze
  GOAL_STATUS_KINDS = { on_track: :success, attention: :warning, behind: :danger }.freeze

  def goal_month_nav(month, path_name)
    tag.div(class: 'dashboard-filter-bar mb-4', id: 'goal_month_nav') do
      safe_join([
                  tag.span(t('goals.month_nav.label'), class: 'dashboard-filter-label'),
                  tag.div(class: 'dashboard-segmented', role: 'group', aria: { label: t('goals.month_nav.label') }) do
                    safe_join([
                                goal_month_link(month.prev_month, path_name, :'chevron-left', t('goals.month_nav.previous')),
                                tag.span(goal_month_name(month), class: 'btn btn-sm btn-primary'),
                                goal_month_link(month.next_month, path_name, :'chevron-right', t('goals.month_nav.next')),
                              ])
                  end,
                ])
    end
  end

  def goal_month_name(month)
    l(month, format: :month_name).capitalize
  end

  def goal_month_param(month)
    month.strftime(RevenueGoal::MONTH_FORMAT)
  end

  def goal_money(cents)
    return t('goals.no_goal') if cents.nil?

    tax_money(Money.from_cents(cents))
  end

  def goal_ratio(ratio)
    return t('goals.no_goal') if ratio.nil?

    number_to_percentage(ratio * 100, precision: 1)
  end

  def goal_status_badge(row)
    return status_badge(t('goals.no_goal'), kind: :secondary) unless row.status

    status_badge(t(row.status, scope: 'goals.statuses'), kind: GOAL_STATUS_KINDS.fetch(row.status))
  end

  def goal_status_kind(row)
    GOAL_STATUS_KINDS.fetch(row.status, :dark)
  end

  def goal_company_cards(dashboard)
    company = dashboard.company

    safe_join([
                counter_card(:dark, t('goals.show.goal'), goal_money(company.goal_cents), col_class: GOAL_CARD_COLUMNS),
                counter_card(:primary, t('goals.show.realized'), goal_money(company.realized_cents), col_class: GOAL_CARD_COLUMNS),
                counter_card(:warning, t('goals.show.missing'), goal_money(company.missing_cents), col_class: GOAL_CARD_COLUMNS),
                counter_card(goal_status_kind(company), t('goals.show.ratio'), goal_ratio(company.ratio), col_class: GOAL_CARD_COLUMNS),
                counter_card(goal_status_kind(company), t('goals.show.projected'), goal_money(company.projected_cents), col_class: GOAL_CARD_COLUMNS),
                counter_card(:dark, t('goals.show.required_daily'), goal_money(dashboard.required_daily_cents), col_class: GOAL_CARD_COLUMNS),
              ])
  end

  def goal_progress(row)
    return unless row.goal?

    tag.progress(goal_ratio(row.ratio), value: [row.realized_cents, row.goal_cents].min, max: row.goal_cents,
                                        class: "goal-progress goal-progress-#{goal_status_kind(row)}", aria: { label: t('goals.show.ratio') })
  end

  def goal_pace_note(dashboard)
    pace = dashboard.pace
    return t('goals.show.pace_notes.closed') if pace.closed?
    return t('goals.show.pace_notes.not_started') unless pace.started?
    return t('goals.show.pace_notes.learned') if pace.learned?

    t('goals.show.pace_notes.business_days', elapsed: pace.elapsed_business_days, total: pace.business_days.size)
  end

  def goal_missing_note(dashboard)
    return if dashboard.company.goal?

    tag.p(class: 'small text-muted mb-3', id: 'goal_missing_note') do
      safe_join([t('goals.show.missing_goal'), goal_registration_link(dashboard.month)], ' ')
    end
  end

  def goal_registration_link(month)
    link_to t('goals.show.register_goals'), revenue_goals_path(month: goal_month_param(month)) if can?(:read, :revenue_goals)
  end

  def goal_registration_button(month)
    return unless can?(:read, :revenue_goals)

    link_to revenue_goals_path(month: goal_month_param(month)), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:bullseye, class: 'me-2'), t('goals.show.register_goals')])
    end
  end

  def goal_vehicles_body(dashboard, rows)
    return render('shared/no_content') if rows.empty?

    render 'goals/vehicles_table', rows:, third_party_row: dashboard.third_party_row
  end

  def goal_position(position, row_counter)
    position || (row_counter + 1)
  end

  def goal_sort_columns
    [[t('goals.show.columns.realized'), :realized, :desc], [t('goals.show.columns.ratio'), :ratio, :desc]]
  end

  private

  def goal_month_link(month, path_name, icon_name, label)
    link_to(public_send(path_name, request.query_parameters.except('month').merge(month: goal_month_param(month))),
            class: 'btn btn-sm btn-outline-secondary', title: label, aria: { label: }) do
      icon(icon_name)
    end
  end
end
