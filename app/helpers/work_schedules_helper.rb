module WorkSchedulesHelper
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
    case sunday.status
    when :taken then status_badge(t('work_schedules.sunday.taken'), kind: :success)
    when :due then status_badge(t('work_schedules.sunday.due'), kind: :warning)
    when :overdue then status_badge(t('work_schedules.sunday.overdue', date: l(sunday.due_on, format: :chart_week)), kind: :danger)
    when :on_track then status_badge(t('work_schedules.sunday.on_track', date: l(sunday.due_on, format: :chart_week)), kind: :info)
    else status_badge(t('work_schedules.sunday.unknown'), kind: :secondary)
    end
  end

  def work_schedule_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  private

  def work_schedule_entry_menu(employee, schedule)
    Menu.new(name: :schedule, record: employee, url: new_work_schedule_day_path(employee_id: employee.id, date: schedule.entry_date.iso8601),
             icon: :'calendar-plus', data: { turbo_stream: true })
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
