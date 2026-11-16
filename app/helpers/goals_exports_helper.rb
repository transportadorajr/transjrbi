module GoalsExportsHelper
  def goals_xlsx_sheets(dashboard, section, rows)
    [Export::Sheet.new(name: t('goals.xlsx.summary'), columns: goals_xlsx_summary_columns(dashboard), rows: [dashboard.company]),
     Export::Sheet.new(name: t(section, scope: 'goals.show.dimension_titles'), columns: goals_xlsx_row_columns(dashboard, section),
                       rows: goals_xlsx_rows(dashboard, section, rows))]
  end

  private

  def goals_xlsx_summary_columns(dashboard)
    [xlsx_field(t('goals.xlsx.month')) { goal_month_name(dashboard.month) },
     *goals_xlsx_month_columns,
     xlsx_field(t('goals.show.projected'), :money, &:projected_cents),
     xlsx_field(t('goals.show.required_daily'), :money) { dashboard.required_daily_cents },
     goals_xlsx_status_column,
     *(goals_xlsx_week_columns if dashboard.week?)]
  end

  def goals_xlsx_row_columns(dashboard, section)
    [xlsx_field(t(section, scope: 'goals.sections'), &:label),
     *goals_xlsx_month_columns,
     xlsx_field(t('goals.show.columns.projected'), :money, &:projected_cents),
     *(goals_xlsx_week_columns if dashboard.week? && section != :vehicles),
     goals_xlsx_status_column]
  end

  def goals_xlsx_rows(dashboard, section, rows)
    extra_row = section == :vehicles ? dashboard.third_party_row : dashboard.breakdown_extra_row(section)

    [*rows, extra_row].compact
  end

  def goals_xlsx_month_columns
    [xlsx_field(t('goals.show.columns.goal'), :money, &:goal_cents),
     xlsx_field(t('goals.show.columns.realized'), :money, &:realized_cents),
     xlsx_field(t('goals.show.columns.missing'), :money, &:missing_cents),
     xlsx_field(t('goals.show.columns.ratio'), :percentage) { |row| row.ratio&.*(100) }]
  end

  def goals_xlsx_week_columns
    [xlsx_field(t('goals.show.columns.week_goal'), :money, &:week_goal_cents),
     xlsx_field(t('goals.show.columns.week_realized'), :money, &:week_realized_cents),
     xlsx_field(t('goals.show.columns.week_ratio'), :percentage) { |row| row.week_ratio&.*(100) }]
  end

  def goals_xlsx_status_column
    xlsx_field(t('goals.show.columns.status')) { |row| row.status ? t(row.status, scope: 'goals.statuses') : t('goals.no_goal') }
  end
end
