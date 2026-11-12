class WorkshopEmployeesController < BaseController
  include MaintenanceFeature

  has_scope :by_name, as: :name
  has_scope :by_role_type, as: :role_type

  before_action :set_workshop_employee, only: %i[edit update]

  def index
    authorize!(:read, :workshop_employees)

    @workshop_employees = listing_page(apply_sort(apply_scopes(current_tenant.workshop_employees), :name, :id))
  end

  def new
    authorize!(:create, :workshop_employees)

    @workshop_employee_form = WorkshopEmployeeForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :workshop_employees)

    @workshop_employee_form = WorkshopEmployeeForm.for_workshop_employee(@workshop_employee)
  end

  def create
    authorize!(:create, :workshop_employees)

    @workshop_employee_form = WorkshopEmployeeForm.new(tenant: current_tenant, **workshop_employee_params)

    if @workshop_employee_form.save
      redirect_to workshop_employees_path, notice: t('.success')
    else
      flash.now[:alert] = @workshop_employee_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :workshop_employees)

    @workshop_employee_form = WorkshopEmployeeForm.for_workshop_employee(@workshop_employee)
    @workshop_employee_form.assign_attributes(workshop_employee_params)

    if @workshop_employee_form.save
      redirect_to workshop_employees_path, notice: t('.success')
    else
      flash.now[:alert] = @workshop_employee_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_workshop_employee
    @workshop_employee = current_tenant.workshop_employees.find(params.expect(:id))
  end

  def workshop_employee_params
    params.expect(workshop_employee: %i[name role_type active])
  end
end
