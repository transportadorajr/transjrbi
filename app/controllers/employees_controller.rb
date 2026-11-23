class EmployeesController < BaseController
  include Activation

  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type
  has_scope :by_work_schedule_type, as: :work_schedule_type
  has_scope :by_status, as: :status

  before_action :set_employee, only: %i[show edit update activate deactivate]

  def index
    authorize!(:read, :employees)

    @employees = listing_page(apply_sort(apply_scopes(current_tenant.employees.preload(:driver)), :name, :id))
  end

  def show
    authorize!(:read, :employees)
  end

  def new
    authorize!(:create, :employees)

    @employee_form = EmployeeForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :employees)

    @employee_form = EmployeeForm.for_employee(@employee)
  end

  def create
    authorize!(:create, :employees)

    @employee_form = EmployeeForm.new(tenant: current_tenant, **employee_params)

    if @employee_form.save
      redirect_to employee_path(@employee_form.employee), notice: t('.success')
    else
      flash.now[:alert] = @employee_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :employees)

    @employee_form = EmployeeForm.for_employee(@employee)
    @employee_form.assign_attributes(employee_params)

    if @employee_form.save
      redirect_to employee_path(@employee), notice: t('.success')
    else
      flash.now[:alert] = @employee_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def activation_form
    EmployeeForm.for_employee(@employee)
  end

  def set_employee
    @employee = current_tenant.employees.preload(:driver, :workshop_employee).find(params.expect(:id))
  end

  def employee_params
    params.expect(
      employee: %i[name nickname legal_id company_type registration role cost_center gender_type born_on admitted_on
                   work_schedule_type workshop_employee_id active],
    )
  end
end
