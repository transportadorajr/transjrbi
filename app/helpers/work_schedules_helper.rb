module WorkSchedulesHelper
  WORK_SCHEDULE_SUNDAY_KINDS = { taken: :success, due: :warning, overdue: :danger, on_track: :info, unknown: :secondary }.freeze
  WORK_SCHEDULE_ALERT_KINDS = {
    few_days_off: :warning, trip_week_without_day_off: :warning, sunday_overdue: :danger, accumulated_days_off: :primary,
    next_week_missing: :warning
  }.freeze

  def work_schedule_week_label(schedule)
    t('work_schedules.index.week', start: l(schedule.dates.first), finish: l(schedule.dates.last))
  end

  def work_schedule_week_path(week_start)
    work_schedules_path(request.query_parameters.except('page').merge('week' => week_start.iso8601))
  end

  def work_schedule_day_label(date)
    l(date, format: :week_day)
  end

  def work_schedule_day_tag(day)
    case day.status
    when :trip then status_badge(t('work_schedules.status.trip'), kind: :info)
    when :day_off then work_schedule_day_off_tag(day)
    when :leave then work_schedule_leave_tag(day)
    else content_tag(:span, t('work_schedules.status.work'), class: 'small text-body-secondary')
    end
  end

  def work_schedule_day_cell(day)
    return work_schedule_day_tag(day) if day.entry.nil? || cannot?(:read, :work_schedules)

    link_to work_schedule_day_path(day.entry), class: 'text-decoration-none', data: { turbo_stream: true },
                                               title: t('work_schedule_days.entry.open', date: l(day.date)) do
      work_schedule_day_tag(day)
    end
  end

  def work_schedule_menu(employee, schedule)
    menus = []

    menus << work_schedule_entry_menu(employee, schedule) if can?(:create, :work_schedules)

    menus
  end

  def work_schedule_days_off_tag(row)
    status_badge(
      t('work_schedules.days_off', count: row.days_off_count, total: Dashboard::WorkSchedule::DAYS_OFF_PER_WEEK),
      kind: row.owed_days_off.zero? ? :success : :warning,
    )
  end

  def work_schedule_sunday_tag(sunday)
    status_badge(work_schedule_sunday_text(sunday), kind: WORK_SCHEDULE_SUNDAY_KINDS.fetch(sunday.status))
  end

  def work_schedule_sunday_text(sunday)
    t("work_schedules.sunday.#{sunday.status}", date: (l(sunday.due_on, format: :chart_week) if sunday.due_on))
  end

  def work_schedule_alerts_tag(row, wrapper_class: 'd-flex flex-column align-items-end gap-1')
    return if row.alerts.empty?

    content_tag(:div, class: wrapper_class) do
      safe_join(row.alerts.map { |kind| status_badge(work_schedule_alert_text(kind), kind: WORK_SCHEDULE_ALERT_KINDS.fetch(kind)) })
    end
  end

  def work_schedule_alert_text(kind)
    t("work_schedules.alerts.#{kind}", total: Dashboard::WorkSchedule::DAYS_OFF_PER_WEEK)
  end

  def work_schedule_alerts_text(row)
    row.alerts.map { |kind| work_schedule_alert_text(kind) }.join(', ')
  end

  def work_schedule_alert_options
    options = [[t('work_schedules.filters.any_alert'), Dashboard::WorkSchedule::ANY_ALERT],
               *Dashboard::WorkSchedule::ALERTS.map { |kind| [work_schedule_alert_text(kind), kind] }]

    options_for_select(options, params[:alert])
  end

  def work_schedule_day_text(day)
    case day.status
    when :day_off then work_schedule_day_off_text(day)
    when :leave then t('work_schedules.text.leave', reason: WorkScheduleDay.human_enum_name(:leave_reason_type, day.leave_reason_type))
    else t("work_schedules.status.#{day.status}")
    end
  end

  def work_schedule_pdf_report(schedule, rows)
    PdfReport.new(
      title: t('work_schedules.index.pdf.header'),
      subtitle: work_schedule_week_label(schedule),
      columns: [pdf_column(Employee.human_attribute_name(:name), '2fr'),
                *schedule.dates.map { |date| pdf_column(work_schedule_day_label(date), '1fr') },
                pdf_column(t('work_schedules.index.days_off'), align: :right), pdf_column(t('work_schedules.index.sunday')),
                pdf_column(t('work_schedules.index.alerts_column'))],
      rows: rows.map do |row|
        [row.employee.name, *row.days.map { |day| work_schedule_day_text(day) }, row.days_off_count, work_schedule_sunday_text(row.sunday),
         work_schedule_alerts_text(row)]
      end,
    )
  end

  def work_schedule_xlsx_sheets(schedule, rows)
    columns = [xlsx_field(Employee.human_attribute_name(:name)) { |row| row.employee.name },
               xlsx_field(Employee.human_attribute_name(:company_type)) { |row| row.employee.company_type_name },
               *schedule.dates.each_with_index.map do |date, index|
                 xlsx_field(work_schedule_day_label(date)) { |row| work_schedule_day_text(row.days[index]) }
               end,
               xlsx_field(t('work_schedules.index.days_off'), :integer, &:days_off_count),
               xlsx_field(t('work_schedules.index.sunday')) { |row| work_schedule_sunday_text(row.sunday) },
               xlsx_field(t('work_schedules.index.alerts_column')) { |row| work_schedule_alerts_text(row) }]

    [Export::Sheet.new(name: t('work_schedules.index.title'), columns:, rows:)]
  end

  def work_schedule_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  private

  def work_schedule_entry_menu(employee, schedule)
    Menu.new(name: :schedule, record: employee, url: new_work_schedule_day_path(employee_id: employee.id, date: schedule.entry_date.iso8601),
             icon: :'calendar-plus', data: { turbo_stream: true })
  end

  def work_schedule_day_off_text(day)
    return t('work_schedules.status.day_off') if day.city.nil?

    t("work_schedules.text.#{day.city.base? ? :day_off_at_base : :day_off_away}", city: tax_city(day.city.name, day.city.state))
  end

  def work_schedule_day_off_tag(day)
    return status_badge(t('work_schedules.status.day_off'), kind: :success) if day.city.nil?

    safe_join([
                status_badge(t("work_schedules.status.#{day.city.base? ? :day_off_at_base : :day_off_away}"),
                             kind: day.city.base? ? :success : :warning),
                content_tag(:small, tax_city(day.city.name, day.city.state), class: 'd-block text-body-secondary mt-1'),
              ])
  end

  def work_schedule_leave_tag(day)
    safe_join([
                status_badge(t('work_schedules.status.leave'), kind: :danger),
                content_tag(:small, WorkScheduleDay.human_enum_name(:leave_reason_type, day.leave_reason_type),
                            class: 'd-block text-body-secondary mt-1'),
              ])
  end
end
