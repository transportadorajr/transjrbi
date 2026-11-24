module AbsencesHelper
  ABSENCE_KINDS = { vacation: :primary, leave: :warning }.freeze

  def absence_month_label(calendar)
    l(calendar.month, format: :month_name).capitalize
  end

  def absence_month_path(month)
    absences_path(month: month.strftime('%Y-%m'))
  end

  def absence_weekday_names
    t('date.abbr_day_names')
  end

  def absence_employee_label(employee)
    employee.nickname.presence || employee.name
  end

  def absence_badge(absence)
    status_badge(absence_employee_label(absence.employee), kind: ABSENCE_KINDS.fetch(absence.kind))
  end

  def absence_kind_badge(absence)
    status_badge(absence_kind_text(absence), kind: ABSENCE_KINDS.fetch(absence.kind))
  end

  def absence_kind_text(absence)
    if absence.vacation?
      t('absences.kind.vacation')
    else
      t('absences.kind.leave', reason: WorkScheduleDay.human_enum_name(:leave_reason_type, absence.leave_reason_type))
    end
  end

  def absence_calendar_cell(day)
    return tag.div(class: 'absence-calendar-cell absence-calendar-cell-empty') if day.nil?

    tag.div(class: ['absence-calendar-cell', ('absence-calendar-cell-today' if day.date == Date.current)]) do
      safe_join([tag.span(day.date.day, class: 'absence-calendar-day'),
                 tag.div(safe_join(day.absences.map { |absence| absence_badge(absence) }), class: 'd-flex flex-column gap-1')])
    end
  end

  def absence_day_label(date)
    l(date, format: :with_weekday)
  end
end
