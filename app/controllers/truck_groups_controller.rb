class TruckGroupsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :set_truck_group, only: %i[show edit update destroy]

  def index
    authorize!(:read, :truck_groups)

    truck_groups = current_tenant.truck_groups
    counted_truck_groups = apply_scopes(truck_groups, params.except(:status))

    @truck_groups = apply_scopes(truck_groups).order(:name, :id).page(params[:page])
    @total_count = counted_truck_groups.count
    @active_count = counted_truck_groups.activated.count
    @deactivated_count = counted_truck_groups.not_activated.count
  end

  def show
    authorize!(:read, :truck_groups)

    month_fuels = @truck_group.freight_expenses.by_period(Date.current.beginning_of_month, Date.current.end_of_month)
    @month_fuels_count = month_fuels.count
    @month_fuels_amount = Money.from_cents(month_fuels.sum(:amount_cents))
  end

  def new
    authorize!(:create, :truck_groups)

    @truck_group_form = TruckGroupForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :truck_groups)

    @truck_group_form = TruckGroupForm.for_truck_group(@truck_group)
  end

  def create
    authorize!(:create, :truck_groups)

    @truck_group_form = TruckGroupForm.new(tenant: current_tenant, **truck_group_params)

    if @truck_group_form.save
      redirect_to truck_group_path(@truck_group_form.truck_group), notice: t('.success')
    else
      flash.now[:alert] = @truck_group_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :truck_groups)

    @truck_group_form = TruckGroupForm.for_truck_group(@truck_group)
    @truck_group_form.assign_attributes(truck_group_params)

    if @truck_group_form.save
      redirect_to truck_group_path(@truck_group), notice: t('.success')
    else
      flash.now[:alert] = @truck_group_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :truck_groups)

    if @truck_group.destroy
      redirect_to truck_groups_path, notice: t('.success')
    else
      redirect_to truck_groups_path, alert: @truck_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_truck_group
    @truck_group = current_tenant.truck_groups.find(params.expect(:id))
  end

  def truck_group_params
    params.expect(truck_group: [:name, :fuel_percentage, :remaining_axles, :active, { axles: [] }])
  end
end
