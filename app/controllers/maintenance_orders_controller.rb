class MaintenanceOrdersController < BaseController
  include MaintenanceFeature

  has_scope :by_number, as: :number
  has_scope :by_plate, as: :plate
  has_scope :by_status_type, as: :status_type
  has_scope :by_maintenance_type, as: :maintenance_type
  has_scope :by_priority_type, as: :priority_type
  has_scope :by_affected_system_type, as: :affected_system_type
  has_scope :by_opened_from, as: :start_date
  has_scope :by_opened_until, as: :end_date

  before_action :set_maintenance_order, only: %i[show edit update start wait_parts cancel finishing finish]
  before_action :require_editable_order, only: %i[edit update finishing finish]
  before_action :load_form_options, only: %i[new create edit update]

  def index
    authorize!(:read, :maintenance_orders)

    orders = current_tenant.maintenance_orders
    @maintenance_orders = listing_page(apply_sort(apply_scopes(orders), number: :desc))
    @pending_count = orders.pending.count
    @stopped_count = orders.stopped.count
    @finished_this_month_count = orders.finished.where(finished_at: Time.current.all_month).count
  end

  def show
    authorize!(:read, :maintenance_orders)

    @parts = @maintenance_order.parts.order(:id)
    @labors = @maintenance_order.labors.preload(:workshop_employee).order(:worked_on, :start_time, :id)
    @services = @maintenance_order.services.preload(:supplier).order(:id)
    @labor_hours = @labors.sum(:hours)

    respond_to do |format|
      format.html
      format.pdf { render typst: nil, filename: t('.pdf.filename', number: @maintenance_order.number) }
    end
  end

  def new
    authorize!(:create, :maintenance_orders)

    @maintenance_order_form = MaintenanceOrderForm.new(tenant: current_tenant, opened_at: Time.current.change(sec: 0))
  end

  def edit
    authorize!(:update, :maintenance_orders)

    @maintenance_order_form = MaintenanceOrderForm.for_maintenance_order(@maintenance_order)
  end

  def create
    authorize!(:create, :maintenance_orders)

    @maintenance_order_form = MaintenanceOrderForm.new(tenant: current_tenant, opened_by: current_user, **maintenance_order_params)

    if @maintenance_order_form.save
      redirect_to maintenance_order_path(@maintenance_order_form.maintenance_order),
                  notice: t('.success', number: @maintenance_order_form.maintenance_order.number)
    else
      flash.now[:alert] = @maintenance_order_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :maintenance_orders)

    @maintenance_order_form = MaintenanceOrderForm.for_maintenance_order(@maintenance_order)
    @maintenance_order_form.assign_attributes(maintenance_order_params)

    if @maintenance_order_form.save
      redirect_to maintenance_order_path(@maintenance_order), notice: t('.success')
    else
      flash.now[:alert] = @maintenance_order_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def start
    authorize!(:update, :maintenance_orders)

    change_status(@maintenance_order.validate_start)
  end

  def wait_parts
    authorize!(:update, :maintenance_orders)

    change_status(@maintenance_order.validate_wait_parts)
  end

  def cancel
    authorize!(:update, :maintenance_orders)

    change_status(@maintenance_order.validate_cancel)
  end

  def finishing
    authorize!(:update, :maintenance_orders)

    @finish_form = MaintenanceOrderFinishForm.for_maintenance_order(@maintenance_order)
    render formats: :turbo_stream
  end

  def finish
    authorize!(:update, :maintenance_orders)

    @finish_form = MaintenanceOrderFinishForm.new(maintenance_order: @maintenance_order, **finish_params)

    if @finish_form.save
      redirect_to maintenance_order_path(@maintenance_order), notice: t('.success'), status: :see_other
    else
      render formats: :turbo_stream, status: :unprocessable_content
    end
  end

  private

  def change_status(changed)
    if changed
      redirect_to maintenance_order_path(@maintenance_order), notice: t('.success'), status: :see_other
    else
      redirect_to maintenance_order_path(@maintenance_order), alert: @maintenance_order.errors.full_messages.to_sentence,
                                                              status: :see_other
    end
  end

  def require_editable_order
    return if @maintenance_order.editable?

    redirect_to maintenance_order_path(@maintenance_order), alert: t('maintenance_orders.locked'), status: :see_other
  end

  def finish_params
    params.expect(maintenance_order_finish: MaintenanceOrderFinishForm::PERMITTED_ATTRIBUTES)
  end

  def set_maintenance_order
    @maintenance_order = current_tenant.maintenance_orders.find(params.expect(:id))
  end

  def load_form_options
    @plates = current_tenant.atua_vehicles.active.where.not(plate: [nil, '']).distinct.order(:plate).pluck(:plate)
    @drivers = current_tenant.atua_vehicles.drivers.order(:driver_name)
    @supervisors = current_tenant.workshop_employees.supervisor.active.order(:name)
  end

  def maintenance_order_params
    params.expect(maintenance_order: MaintenanceOrderForm::PERMITTED_ATTRIBUTES)
  end
end
