module GoalsHelper
  GOAL_CARD_COLUMNS = 'col-6 col-xl-4'.freeze
  GOAL_WEEK_CARD_COLUMNS = 'col-6 col-xl-3'.freeze
  GOAL_STATUS_KINDS = { on_track: :success, attention: :warning, behind: :danger }.freeze
  GOAL_REALIZED_STYLE = { color: ChartsHelper::BRAND_BLUE, dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE } }.freeze
  GOAL_EXPECTED_STYLE = { color: RevenueProjectionHistoriesHelper::HISTORY_PROJECTED_ORANGE,
                          dataset: { borderColor: RevenueProjectionHistoriesHelper::HISTORY_PROJECTED_ORANGE,
                                     backgroundColor: RevenueProjectionHistoriesHelper::HISTORY_PROJECTED_ORANGE, borderDash: [6, 4] } }.freeze
  GOAL_CHART_SERIES = [GOAL_REALIZED_STYLE, GOAL_EXPECTED_STYLE].freeze
  GOAL_DATE_TICKS = 8

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

  def goal_week_value(row, value)
    return t('goals.show.no_week') if row.week_realized_cents.nil?

    value
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

  def goal_week(dashboard)
    return unless dashboard.week?

    render 'goals/week', dashboard:
  end

  def goal_week_title(week)
    t('goals.show.week_title', start: l(week.period.first, format: :chart_week), finish: l(week.period.last, format: :chart_week))
  end

  def goal_week_cards(row)
    safe_join([
                counter_card(:dark, t('goals.show.week_goal'), goal_money(row.week_goal_cents), col_class: GOAL_WEEK_CARD_COLUMNS),
                counter_card(:primary, t('goals.show.week_realized'), goal_money(row.week_realized_cents), col_class: GOAL_WEEK_CARD_COLUMNS),
                counter_card(:warning, t('goals.show.missing'), goal_money(row.week_missing_cents), col_class: GOAL_WEEK_CARD_COLUMNS),
                counter_card(:dark, t('goals.show.ratio'), goal_ratio(row.week_ratio), col_class: GOAL_WEEK_CARD_COLUMNS),
              ])
  end

  def goal_chart(dashboard)
    line_chart(dashboard.chart_data.zip(GOAL_CHART_SERIES).map { |serie, style| serie.merge(style) },
               height: ChartsHelper::CHART_HEIGHT, legend: 'bottom', discrete: true, points: false, **chart_money_options,
               library: chart_bar_library(:x).deep_merge(scales: { x: { ticks: { autoSkip: true, maxTicksLimit: GOAL_DATE_TICKS, maxRotation: 0 } } }))
  end

  def goal_tab_nav(prefix, tabs, active: tabs.keys.first)
    tag.ul(class: 'nav nav-pills goal-tabs', id: "#{prefix}_tabs", role: 'tablist') do
      safe_join(tabs.map { |section, label| goal_tab_item(prefix, section, label, section == active) })
    end
  end

  def goal_tab_pane(prefix, section, active, &)
    tag.div(class: ['tab-pane fade', { 'show active' => active }], id: "#{prefix}_#{section}_pane", role: 'tabpanel',
            aria: { labelledby: "#{prefix}_#{section}_tab" }, tabindex: 0, &)
  end

  def goal_dimension_bar(filter_form)
    tag.div(class: 'dashboard-filter-bar mb-4', id: 'goal_dimension_bar') do
      safe_join([
                  tag.span(t('goals.show.group_by'), class: 'dashboard-filter-label'),
                  tag.div(class: 'dashboard-segmented', role: 'group', aria: { label: t('goals.show.group_by') }) do
                    safe_join(Dashboard::Goals::DIMENSIONS.keys.map { |dimension| goal_dimension_link(dimension, filter_form) })
                  end,
                ])
    end
  end

  def goal_dimension_body(dashboard, section, rows)
    return goal_vehicles_body(dashboard, section, rows) if Dashboard::Goals.vehicle_section?(section)

    goal_breakdown_body(dashboard, section, rows)
  end

  def goal_dimension_sort_menu(section)
    sort_menu(goal_sort_columns) if Dashboard::Goals.vehicle_section?(section)
  end

  def goal_vehicle_type_nav(section)
    return unless Dashboard::Goals.vehicle_section?(section)

    tag.div(class: 'dashboard-segmented mt-3', id: 'goal_vehicle_type_nav', role: 'group', aria: { label: t('goals.show.vehicle_type') }) do
      safe_join(Dashboard::Goals::VEHICLE_SECTIONS.map { |vehicle_type, vehicle_section| goal_vehicle_type_link(vehicle_type, vehicle_section == section) })
    end
  end

  def goal_breakdown_body(dashboard, section, rows)
    extra_row = dashboard.breakdown_extra_row(section)
    return render('shared/no_content') if rows.empty? && extra_row.nil?

    render 'goals/breakdown_table', section:, rows:, extra_row: goal_last_page_row(rows, extra_row), month: dashboard.month
  end

  def goal_last_page_row(rows, row)
    row if rows.current_page >= rows.total_pages
  end

  def goal_plate_tag(plate)
    tag.span(plate, class: 'goal-plate')
  end

  def goal_vehicle_label(row)
    return row.label if row.key == Dashboard::Goals::THIRD_PARTY_KEY

    goal_plate_tag(row.label)
  end

  def goal_row_menu(row, month)
    menus = []
    menus << goal_projection_menu(row, month) if row.cut && goal_projection_allowed?
    menus
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

  def goal_vehicles_body(dashboard, section, rows)
    return render('shared/no_content') if rows.empty?

    render 'goals/vehicles_table', section:, rows:, third_party_row: goal_last_page_row(rows, dashboard.third_party_row(section)), month: dashboard.month
  end

  def goal_third_party_row(row, month)
    return unless row

    render 'goals/vehicle_row', row:, position: '', month:
  end

  def goal_breakdown_extra_row(row, month)
    return unless row

    render 'goals/breakdown_row', row:, month:
  end

  def goal_position(position, row_counter, offset)
    position || (offset + row_counter + 1)
  end

  def goal_sort_columns
    [[t('goals.show.columns.realized'), :realized, :desc], [t('goals.show.columns.ratio'), :ratio, :desc]]
  end

  private

  def goal_projection_allowed?
    Dashboard::RevenueProjection.enabled?(Current.tenant) && can?(:read, :revenue_projection)
  end

  def goal_projection_menu(row, month)
    Menu.new(name: :projection, record: row, url: revenue_projection_history_path(start_date: month.beginning_of_month, end_date: month.end_of_month, **row.cut),
             icon: :'graph-up-arrow')
  end

  def goal_dimension_link(dimension, filter_form)
    variation = dimension == filter_form.dimension_value ? 'btn-primary' : 'btn-outline-secondary'
    link_to t(dimension, scope: 'goals.dimensions'), goals_path(**request.query_parameters.symbolize_keys.except(:sort, :direction), dimension:),
            class: "btn btn-sm #{variation}"
  end

  def goal_vehicle_type_link(vehicle_type, active)
    link_to t(vehicle_type, scope: 'goals.vehicle_types'),
            goals_path(**request.query_parameters.symbolize_keys.except(:sort, :direction, :page), vehicle_type:, anchor: 'goal_vehicle_type_nav'),
            class: "btn btn-sm #{active ? 'btn-primary' : 'btn-outline-secondary'}", aria: { current: (true if active) }
  end

  def goal_tab_item(prefix, section, label, active)
    tag.li(class: 'nav-item', role: 'presentation') do
      button_tag(label, type: 'button', class: ['nav-link', { active: }], id: "#{prefix}_#{section}_tab", role: 'tab',
                        data: { bs_toggle: 'tab', bs_target: "##{prefix}_#{section}_pane" }, aria: { controls: "#{prefix}_#{section}_pane", selected: active })
    end
  end

  def goal_month_link(month, path_name, icon_name, label)
    link_to(public_send(path_name, request.query_parameters.except('month').merge(month: goal_month_param(month))),
            class: 'btn btn-sm btn-outline-secondary', title: label, aria: { label: }) do
      icon(icon_name)
    end
  end
end
