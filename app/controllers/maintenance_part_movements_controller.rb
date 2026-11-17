class MaintenancePartMovementsController < BaseController
  include MaintenanceFeature

  has_scope :by_maintenance_part, as: :maintenance_part_id
  has_scope :by_movement_type, as: :movement_type
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :maintenance_parts)

    @maintenance_parts = current_tenant.maintenance_parts.order(:description)
    @movements = listing_page(apply_scopes(current_tenant.maintenance_part_movements)
                   .preload(:maintenance_part, :supplier, :maintenance_order, :created_by).order(moved_on: :desc, id: :desc))
  end

  def new
    authorize!(:create, :maintenance_parts)

    @movement_form = MaintenancePartMovementForm.new(tenant: current_tenant, moved_on: Time.zone.today,
                                                     **params.permit(:movement_type, :maintenance_part_id).to_h.symbolize_keys)
  end

  def create
    authorize!(:create, :maintenance_parts)

    @movement_form = MaintenancePartMovementForm.new(tenant: current_tenant, created_by: current_user, **movement_params)

    if @movement_form.save
      redirect_to maintenance_part_movements_path, notice: t(".#{@movement_form.movement_type}")
    else
      flash.now[:alert] = @movement_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private

  def movement_params
    params.expect(maintenance_part_movement: MaintenancePartMovementForm::PERMITTED_ATTRIBUTES)
  end
end
