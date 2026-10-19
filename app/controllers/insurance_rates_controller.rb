class InsuranceRatesController < BaseController
  has_scope :by_valid_from_start, as: :start_date
  has_scope :by_valid_from_end, as: :end_date

  before_action :set_insurance_rate, only: %i[show edit update destroy]

  def index
    authorize!(:read, :insurance_rates)

    @insurance_rates = apply_scopes(current_tenant.insurance_rates).order(valid_from: :desc, id: :desc).page(params[:page])
    @current_insurance_rate = InsuranceRate.current(current_tenant)
  end

  def show
    authorize!(:read, :insurance_rates)

    @current_insurance_rate = InsuranceRate.current(current_tenant)
    @expenses_count = @insurance_rate.freight_expenses.count
    @expenses_total = Money.from_cents(@insurance_rate.freight_expenses.sum(:amount_cents))
  end

  def new
    authorize!(:create, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.for_insurance_rate(@insurance_rate)
  end

  def create
    authorize!(:create, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.new(tenant: current_tenant, **insurance_rate_params)

    if @insurance_rate_form.save
      redirect_to insurance_rate_path(@insurance_rate_form.insurance_rate), notice: t('.success')
    else
      flash.now[:alert] = @insurance_rate_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.for_insurance_rate(@insurance_rate)
    @insurance_rate_form.assign_attributes(insurance_rate_params)

    if @insurance_rate_form.save
      redirect_to insurance_rate_path(@insurance_rate), notice: t('.success')
    else
      flash.now[:alert] = @insurance_rate_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :insurance_rates)

    if @insurance_rate.destroy
      redirect_to insurance_rates_path, notice: t('.success')
    else
      redirect_to insurance_rates_path, alert: @insurance_rate.errors.full_messages.to_sentence
    end
  end

  private

  def set_insurance_rate
    @insurance_rate = current_tenant.insurance_rates.find(params.expect(:id))
  end

  def insurance_rate_params
    params.expect(insurance_rate: %i[valid_from insurance_percentage iof_percentage])
  end
end
