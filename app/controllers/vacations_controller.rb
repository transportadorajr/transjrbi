class VacationsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type
  has_scope :by_month, as: :month

  before_action :set_vacation, only: %i[edit update destroy]

  def index
    authorize!(:read, :vacations)

    vacations = current_tenant.vacations.joins(:employee).preload(:employee)
    @vacations = listing_page(apply_sort(apply_scopes(vacations), start_on: :desc, id: :desc))

    respond_with_listing(orientation: :landscape, xlsx: @vacations)
  end

  def new
    authorize!(:create, :vacations)

    @vacation_form = VacationForm.new(tenant: current_tenant, employee_id: params[:employee_id])
  end

  def edit
    authorize!(:update, :vacations)

    @vacation_form = VacationForm.for_vacation(@vacation)
  end

  def create
    authorize!(:create, :vacations)

    @vacation_form = VacationForm.new(tenant: current_tenant, **vacation_params)

    if @vacation_form.save
      redirect_to vacations_path, notice: t('.success')
    else
      flash.now[:alert] = @vacation_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :vacations)

    @vacation_form = VacationForm.for_vacation(@vacation)
    @vacation_form.assign_attributes(vacation_params.except(:employee_id))

    if @vacation_form.save
      redirect_to vacations_path, notice: t('.success')
    else
      flash.now[:alert] = @vacation_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :vacations)

    @vacation.destroy!
    redirect_to vacations_path, notice: t('.success'), status: :see_other
  end

  private

  def set_vacation
    @vacation = current_tenant.vacations.preload(:employee).find(params.expect(:id))
  end

  def vacation_params
    params.expect(vacation: %i[employee_id start_on end_on sold_days notes]).to_h.symbolize_keys
  end
end
