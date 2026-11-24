module UninsuredEmployeesHelper
  def uninsured_employees_menu(employee)
    menus = []

    menus << uninsured_employee_show_menu(employee) if can?(:read, :employees)

    menus
  end

  def uninsured_employees_button
    return unless can?(:read, :life_insurances)

    link_to uninsured_employees_path, class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:'person-exclamation', class: 'me-2'), t('uninsured_employees.index.title')])
    end
  end

  def uninsured_employees_xlsx_sheets(employees)
    columns = [xlsx_field(Employee.human_attribute_name(:name), &:name),
               xlsx_field(Employee.human_attribute_name(:company_type), &:company_type_name),
               xlsx_field(Employee.human_attribute_name(:registration), &:registration),
               xlsx_field(Employee.human_attribute_name(:job_position), &:job_position_name),
               xlsx_field(Employee.human_attribute_name(:admitted_on), :date, &:admitted_on)]

    [Export::Sheet.new(name: t('uninsured_employees.index.title'), columns:, rows: employees)]
  end

  def uninsured_employees_pdf_report(employees)
    PdfReport.new(
      title: t('uninsured_employees.index.pdf.header'),
      columns: [pdf_column(Employee.human_attribute_name(:name), '2fr'), pdf_column(Employee.human_attribute_name(:company_type)),
                pdf_column(Employee.human_attribute_name(:registration)), pdf_column(Employee.human_attribute_name(:job_position), '2fr'),
                pdf_column(Employee.human_attribute_name(:admitted_on))],
      rows: employees.map do |employee|
        [employee.name, employee.company_type_name, tax_value(employee.registration), employee_job_position_name(employee),
         employee_date(employee.admitted_on)]
      end,
    )
  end

  private

  def uninsured_employee_show_menu(employee)
    Menu.new(name: :show, record: employee, url: employee_path(employee), icon: :eye)
  end
end
