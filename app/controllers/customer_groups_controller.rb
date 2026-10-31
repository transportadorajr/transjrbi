class CustomerGroupsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :set_customer_group, only: %i[show edit update destroy regroup]

  def index
    authorize!(:read, :customer_groups)

    customer_groups = current_tenant.customer_groups
    counted_customer_groups = apply_scopes(customer_groups, params.except(:status))

    @customer_groups = apply_sort(apply_scopes(customer_groups), :name, :id).page(params[:page])
    @customer_counts = current_tenant.atua_customers.active.where(customer_group_id: @customer_groups.map(&:id))
      .group(:customer_group_id).count
    @total_count = counted_customer_groups.count
    @active_count = counted_customer_groups.activated.count
    @deactivated_count = counted_customer_groups.not_activated.count
  end

  def show
    authorize!(:read, :customer_groups)

    @customers = apply_sort(@customer_group.customers.active, :name, :id).page(params[:page])
  end

  def new
    authorize!(:create, :customer_groups)

    @customer_group_form = CustomerGroupForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :customer_groups)

    @customer_group_form = CustomerGroupForm.for_customer_group(@customer_group)
  end

  def create
    authorize!(:create, :customer_groups)

    @customer_group_form = CustomerGroupForm.new(tenant: current_tenant, **customer_group_params)

    if @customer_group_form.save
      redirect_to customer_group_path(@customer_group_form.customer_group), notice: t('.success')
    else
      flash.now[:alert] = @customer_group_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :customer_groups)

    @customer_group_form = CustomerGroupForm.for_customer_group(@customer_group)
    @customer_group_form.assign_attributes(customer_group_params)

    if @customer_group_form.save
      redirect_to customer_group_path(@customer_group), notice: t('.success')
    else
      flash.now[:alert] = @customer_group_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :customer_groups)

    if @customer_group.destroy
      redirect_to customer_groups_path, notice: t('.success')
    else
      redirect_to customer_groups_path, alert: @customer_group.errors.full_messages.to_sentence
    end
  end

  def regroup
    authorize!(:update, :customer_groups)

    count = CustomerGroups::RegroupCommand.call(@customer_group)
    FreightExpenses::CalculateJob.perform_later(current_tenant.id) if count.positive?

    redirect_to customer_group_path(@customer_group), notice: t('.success', count:)
  end

  private

  def set_customer_group
    @customer_group = current_tenant.customer_groups.find(params.expect(:id))
  end

  def customer_group_params
    params.expect(customer_group: %i[name terms active])
  end
end
