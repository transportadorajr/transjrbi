class TonnageRatesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_valid_month, as: :valid_month
  has_scope :by_status, as: :status

  before_action :set_tonnage_rate, only: %i[show edit update destroy]

  def index
    authorize!(:read, :tonnage_rates)

    tonnage_rates = current_tenant.tonnage_rates
    counted_tonnage_rates = apply_scopes(tonnage_rates, params.except(:status))

    @tonnage_rates = apply_scopes(tonnage_rates).preload(:customer_group)
      .order(valid_month: :desc, name: :asc, origin_city: :asc, id: :asc).page(params[:page])
    @customer_groups = current_tenant.customer_groups.where(id: current_tenant.tonnage_rates.select(:customer_group_id)).order(:name)
    @total_count = counted_tonnage_rates.count
    @active_count = counted_tonnage_rates.activated.count
    @deactivated_count = counted_tonnage_rates.not_activated.count
  end

  def show
    authorize!(:read, :tonnage_rates)

    @expenses_count = @tonnage_rate.freight_expenses.count
    @expenses_total = Money.from_cents(@tonnage_rate.freight_expenses.sum(:amount_cents))
  end

  def new
    authorize!(:create, :tonnage_rates)

    @tonnage_rate_form = TonnageRateForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :tonnage_rates)

    @tonnage_rate_form = TonnageRateForm.for_tonnage_rate(@tonnage_rate)
  end

  def create
    authorize!(:create, :tonnage_rates)

    @tonnage_rate_form = TonnageRateForm.new(tenant: current_tenant, **tonnage_rate_params)

    if @tonnage_rate_form.save
      redirect_to tonnage_rate_path(@tonnage_rate_form.tonnage_rate), notice: t('.success')
    else
      flash.now[:alert] = @tonnage_rate_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :tonnage_rates)

    @tonnage_rate_form = TonnageRateForm.for_tonnage_rate(@tonnage_rate)
    @tonnage_rate_form.assign_attributes(tonnage_rate_params)

    if @tonnage_rate_form.save
      redirect_to tonnage_rate_path(@tonnage_rate), notice: t('.success')
    else
      flash.now[:alert] = @tonnage_rate_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :tonnage_rates)

    if @tonnage_rate.destroy
      redirect_to tonnage_rates_path, notice: t('.success')
    else
      redirect_to tonnage_rates_path, alert: @tonnage_rate.errors.full_messages.to_sentence
    end
  end

  private

  def set_tonnage_rate
    @tonnage_rate = current_tenant.tonnage_rates.find(params.expect(:id))
  end

  def tonnage_rate_params
    params.expect(tonnage_rate: %i[customer_group_id name nickname origin_city origin_state valid_month rate active])
  end
end
