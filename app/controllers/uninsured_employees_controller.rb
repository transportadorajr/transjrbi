class UninsuredEmployeesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :life_insurances)

    employees = apply_scopes(current_tenant.employees.without_life_insurance).preload(:job_position)
    @employees = listing_page(apply_sort(employees, :name, :id))

    respond_with_listing(xlsx: -> { helpers.uninsured_employees_xlsx_sheets(@employees) })
  end
end
