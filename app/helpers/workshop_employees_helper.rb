module WorkshopEmployeesHelper
  def workshop_employees_menu(workshop_employee)
    menus = []

    menus << workshop_employee_edit_menu(workshop_employee) if can?(:update, :workshop_employees)

    menus
  end

  def workshop_employee_status_badge(workshop_employee)
    if workshop_employee.active?
      status_badge(t('workshop_employees.status.active'), kind: :success)
    else
      status_badge(t('workshop_employees.status.inactive'), kind: :danger)
    end
  end

  def workshop_employee_role_type_options
    options_for_select(WorkshopEmployee.enum_options_for_select(:role_type), params[:role_type])
  end

  def workshop_employee_form_url(workshop_employee_form)
    workshop_employee_form.persisted? ? workshop_employee_path(workshop_employee_form.workshop_employee) : workshop_employees_path
  end

  def workshop_employee_form_submit_label(workshop_employee_form)
    t("helpers.submit.workshop_employee.#{workshop_employee_form.persisted? ? :update : :create}")
  end

  def workshop_employee_create_button
    create_button(t('workshop_employees.index.new_workshop_employee')) if can?(:create, :workshop_employees)
  end

  private

  def workshop_employee_edit_menu(workshop_employee)
    Menu.new(name: :edit, record: workshop_employee, url: edit_workshop_employee_path(workshop_employee), icon: :pencil)
  end
end
