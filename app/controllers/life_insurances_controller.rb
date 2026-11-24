class LifeInsurancesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type
  has_scope :by_employee_status, as: :employee_status

  before_action :set_life_insurance, only: %i[edit update]

  def index
    authorize!(:read, :life_insurances)

    life_insurances = apply_scopes(
      current_tenant.life_insurances.covered_on(Date.current).joins(:employee, :life_insurance_policy).preload(:employee, :life_insurance_policy),
    )
    @premium_totals = life_insurances.premium_totals
    @uninsured_count = apply_scopes(current_tenant.employees.without_life_insurance, params.except(:employee_status)).count
    @deactivated_count = life_insurances.with_deactivated_employee.count
    @life_insurances = listing_page(apply_sort(life_insurances, Employee.arel_table[:name].asc, id: :asc))

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.life_insurances_xlsx_sheets(@life_insurances) })
  end

  def new
    authorize!(:create, :life_insurances)

    @life_insurance_form = LifeInsuranceForm.new(tenant: current_tenant, employee_id: params[:employee_id], included_on: Date.current)
  end

  def edit
    authorize!(:update, :life_insurances)

    @life_insurance_form = LifeInsuranceForm.for_life_insurance(@life_insurance)
  end

  def create
    authorize!(:create, :life_insurances)

    @life_insurance_form = LifeInsuranceForm.new(tenant: current_tenant, **life_insurance_params)

    if @life_insurance_form.save
      redirect_to life_insurances_path, notice: t('.success')
    else
      flash.now[:alert] = @life_insurance_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :life_insurances)

    @life_insurance_form = LifeInsuranceForm.for_life_insurance(@life_insurance)
    @life_insurance_form.assign_attributes(life_insurance_params.except(:employee_id))

    if @life_insurance_form.save
      redirect_to life_insurances_path, notice: t('.success')
    else
      flash.now[:alert] = @life_insurance_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_life_insurance
    @life_insurance = current_tenant.life_insurances.where(excluded_on: nil).preload(:employee, :life_insurance_policy).find(params.expect(:id))
  end

  def life_insurance_params
    params.expect(life_insurance: %i[employee_id included_on capital capital_changed_on]).to_h.symbolize_keys
  end
end
