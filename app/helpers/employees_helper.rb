module EmployeesHelper
  def employees_menu(employee)
    menus = []

    menus << employee_show_menu(employee) if can?(:read, :employees)
    menus << employee_edit_menu(employee) if can?(:update, :employees)
    menus << activation_menu(employee, active: employee.activated?) if can?(:update, :employees)

    menus
  end

  def employee_status_badge(employee)
    if employee.activated?
      status_badge(t('employees.status.active'), kind: :success)
    else
      status_badge(t('employees.status.inactive'), kind: :danger)
    end
  end

  def employee_legal_id(employee)
    employee.legal_id.to_s.sub(/\A(\d{3})(\d{3})(\d{3})(\d{2})\z/, '\1.\2.\3-\4')
  end

  def employee_date(date)
    date ? l(date) : t('tax.blank')
  end

  def employee_driver_code(employee)
    employee.driver_code || t('employees.show.no_driver')
  end

  def employee_workshop_employee_name(employee)
    employee.workshop_employee&.name || t('employees.show.no_workshop_employee')
  end

  def employee_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  def employee_work_schedule_type_options
    options_for_select(Employee.enum_options_for_select(:work_schedule_type), params[:work_schedule_type])
  end

  def employee_status_options
    options_for_select(Employee.statuses, params[:status])
  end

  def employee_workshop_employee_options(employee_form)
    employee_form.available_workshop_employees.map { |workshop_employee| [workshop_employee.name, workshop_employee.id] }
  end

  def employee_job_position_options(employee_form)
    employee_form.available_job_positions.map { |job_position| [job_position.name, job_position.id] }
  end

  def employee_job_position_name(employee)
    employee.job_position_name || t('employees.show.no_job_position')
  end

  def employee_form_url(employee_form)
    employee_form.persisted? ? employee_path(employee_form.employee) : employees_path
  end

  def employee_form_submit_label(employee_form)
    t("helpers.submit.employee.#{employee_form.persisted? ? :update : :create}")
  end

  def employee_create_button
    create_button(t('employees.index.new_employee')) if can?(:create, :employees)
  end

  def employee_edit_button(employee)
    return unless can?(:update, :employees)

    link_to edit_employee_path(employee), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:pencil, class: 'me-2'), t('employees.show.edit')])
    end
  end

  private

  def employee_show_menu(employee)
    Menu.new(name: :show, record: employee, url: employee_path(employee), icon: :eye)
  end

  def employee_edit_menu(employee)
    Menu.new(name: :edit, record: employee, url: edit_employee_path(employee), icon: :pencil)
  end
end
