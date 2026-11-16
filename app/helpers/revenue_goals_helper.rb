module RevenueGoalsHelper
  REVENUE_GOALS_CARD_COLUMNS = 'col-6 col-lg-3'.freeze
  REVENUE_GOALS_SEARCH_MIN_LINES = 8
  REVENUE_GOALS_RATIO_TOKEN = '{ratio}'.freeze

  def revenue_goals_edit_button(month)
    return unless can?(:update, :revenue_goals)

    link_to edit_revenue_goals_path(month: goal_month_param(month)), class: 'btn btn-primary btn-primary-action btn-round' do
      safe_join([icon(:pencil, class: 'me-2'), t('revenue_goals.show.edit')])
    end
  end

  def revenue_goals_replicate_button(month)
    return unless can?(:update, :revenue_goals)

    button_to replicate_revenue_goals_path(month: goal_month_param(month)), class: 'btn btn-outline-secondary btn-round',
                                                                            form: { data: { turbo_confirm: t('revenue_goals.show.confirm_replicate',
                                                                                                             month: goal_month_name(month.prev_month)) } } do
      safe_join([icon(:files, class: 'me-2'), t('revenue_goals.show.replicate')])
    end
  end

  def revenue_goals_panel_button(month)
    return unless can?(:read, :goals)

    link_to goals_path(month: goal_month_param(month)), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:speedometer2, class: 'me-2'), t('revenue_goals.show.panel')])
    end
  end

  def revenue_goals_form_data
    { controller: 'goal-lines', action: 'input->goal-lines#refresh', goal_lines_unit_value: t('number.currency.format.unit'),
      goal_lines_separator_value: t('number.currency.format.separator'), goal_lines_delimiter_value: t('number.currency.format.delimiter'),
      goal_lines_share_value: t('revenue_goals.share', ratio: REVENUE_GOALS_RATIO_TOKEN) }
  end

  def revenue_goals_summary_cards(form)
    cards = [counter_card(:dark, t('revenue_goals.show.totals.company'), goal_money(form.company_cents), col_class: REVENUE_GOALS_CARD_COLUMNS)]
    cards += RevenueGoalsForm::SECTIONS.keys.map do |section|
      counter_card(:primary, t(section, scope: 'revenue_goals.show.totals'), revenue_goals_total(form, section), col_class: REVENUE_GOALS_CARD_COLUMNS)
    end
    safe_join(cards)
  end

  def revenue_goals_tabs(form)
    RevenueGoalsForm::SECTIONS.keys.index_with do |section|
      safe_join([t(section, scope: 'goals.tabs'), tag.span(revenue_goals_filled_count(form, section), class: 'badge rounded-pill goal-tab-count')], ' ')
    end
  end

  def revenue_goals_panes(form, month)
    safe_join(RevenueGoalsForm::SECTIONS.keys.each_with_index.map do |section, index|
      goal_tab_pane('revenue_goals', section, index.zero?) { render 'revenue_goals/section', section:, form:, month: }
    end)
  end

  def revenue_goals_form_panes(builder, form, month)
    safe_join(RevenueGoalsForm::SECTIONS.keys.each_with_index.map do |section, index|
      goal_tab_pane('revenue_goals_form', section, index.zero?) { render 'revenue_goals/lines', f: builder, section:, form:, month: }
    end)
  end

  def revenue_goals_section_body(section, form, month)
    lines = form.public_send(section)
    return render('shared/no_content') if lines.empty?

    render 'revenue_goals/table', section:, lines:, company_cents: form.company_cents, month:
  end

  def revenue_goals_lines_body(builder, section, form, month)
    lines = form.public_send(section)
    return render('shared/no_content') if lines.empty?

    tag.div(class: 'goal-lines', id: "revenue_goals_#{section}_fields") do
      builder.simple_fields_for(section, lines) { |line_builder| render 'revenue_goals/line_fields', f: line_builder, section:, month: }
    end
  end

  def revenue_goals_search(section, lines)
    return if lines.size < REVENUE_GOALS_SEARCH_MIN_LINES

    search_field_tag("#{section}_search", nil, class: 'form-control form-control-sm bg-light goal-section-search', placeholder: t(section, scope: 'revenue_goals.search'),
                                               aria: { label: t(section, scope: 'revenue_goals.search') }, autocomplete: 'off',
                                               data: { action: 'input->goal-lines#filter', section: })
  end

  def revenue_goals_target_label(section, line)
    return goal_plate_tag(line.name) if section == :vehicles

    line.name
  end

  def revenue_goals_amount(cents)
    return tag.span(t('goals.no_goal'), class: 'text-muted fw-normal') if cents.nil?

    goal_money(cents)
  end

  def revenue_goals_share(cents, company_cents)
    return tag.span(t('revenue_goals.no_share'), class: 'text-muted') unless cents && company_cents&.positive?

    ratio = cents.to_d / company_cents
    tag.div(class: 'goal-share') do
      safe_join([tag.progress(value: [cents, company_cents].min, max: company_cents, class: 'goal-progress goal-progress-sm',
                              aria: { label: t('revenue_goals.show.columns.share') }),
                 tag.span(goal_ratio(ratio), class: 'goal-share-value')])
    end
  end

  def revenue_goals_share_text(cents, company_cents)
    return '' unless company_cents&.positive?

    t('revenue_goals.share', ratio: goal_ratio(cents.to_d / company_cents))
  end

  def revenue_goals_reference_label(month)
    t('revenue_goals.show.columns.reference', month: goal_month_name(month.prev_month))
  end

  def revenue_goals_reference_text(line, month)
    t('revenue_goals.form.reference', month: goal_month_name(month.prev_month), amount: goal_money(line.reference_cents))
  end

  private

  def revenue_goals_total(form, section)
    goal_money(form.total_cents(section))
  end

  def revenue_goals_filled_count(form, section)
    form.public_send(section).count(&:amount_cents)
  end
end
