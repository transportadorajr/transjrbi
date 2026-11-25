module HrPendenciesHelper
  HR_PENDENCY_KINDS = {
    uninsured: :danger, missing_emergency_contact: :warning, risk_assessment_expired: :danger, risk_assessment_expiring: :warning,
    vacation_overdue: :danger, vacation_due_soon: :warning, irregular_days_off: :warning
  }.freeze

  def hr_pendencies_menu(employee)
    menus = []

    menus << hr_pendency_show_menu(employee) if can?(:read, :employees)

    menus
  end

  def hr_pendency_badges(row)
    badges = row.pendencies.map do |kind|
      link_to hr_pendency_path(kind, row.employee), class: 'text-decoration-none' do
        status_badge(hr_pendency_label(kind), kind: HR_PENDENCY_KINDS.fetch(kind))
      end
    end

    content_tag(:div, safe_join(badges, ' '), class: 'd-flex flex-wrap gap-1')
  end

  def hr_pendency_label(kind)
    t("hr_pendencies.kinds.#{kind}", days: hr_pendency_days(kind))
  end

  def hr_pendency_counter_cards(dashboard, counts)
    safe_join(dashboard.kinds.map do |kind|
      counter_card(:warning, hr_pendency_label(kind), counts.fetch(kind), col_class: 'col-12 col-md-6 col-xl-3')
    end)
  end

  def hr_pendency_options(dashboard)
    options_for_select(dashboard.kinds.map { |kind| [hr_pendency_label(kind), kind] }, params[:pendency])
  end

  def hr_pendency_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  private

  def hr_pendency_days(kind)
    case kind
    when :risk_assessment_expiring then RiskAssessment::EXPIRING_SOON_DAYS
    when :vacation_due_soon then VacationPeriod::DUE_SOON_DAYS
    end
  end

  def hr_pendency_path(kind, employee)
    case kind
    when :uninsured then uninsured_employees_path(name: employee.name)
    when :missing_emergency_contact then emergency_contacts_path(name: employee.name, contact: 'missing')
    when :risk_assessment_expired, :risk_assessment_expiring then risk_assessments_path(name: employee.name)
    when :vacation_overdue then vacation_balances_path(name: employee.name, status: 'overdue')
    when :vacation_due_soon then vacation_balances_path(name: employee.name, status: 'due_soon')
    when :irregular_days_off then work_schedules_path(name: employee.name, alert: Dashboard::WorkSchedule::ANY_ALERT)
    end
  end

  def hr_pendency_show_menu(employee)
    Menu.new(name: :show, record: employee, url: employee_path(employee), icon: :eye)
  end
end
