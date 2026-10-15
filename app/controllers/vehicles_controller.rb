class VehiclesController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_category, as: :category
  has_scope :by_ownership, as: :ownership

  def index
    authorize!(:read, :vehicles)

    vehicles = current_tenant.atua_vehicles.active

    @vehicles = apply_scopes(vehicles).order(:plate, :id).page(params[:page])
    @categories = vehicles.where.not(category: nil).distinct.order(:category).pluck(:category)
    @ownerships = vehicles.where.not(ownership: nil).distinct.order(:ownership).pluck(:ownership)
  end

  def show
    authorize!(:read, :vehicles)

    @vehicle = current_tenant.atua_vehicles.active.find(params.expect(:id))
    empty_legs = current_tenant.empty_legs.where(plate: @vehicle.plate)
    @empty_legs = empty_legs.joins(:next_manifest).preload(:origin, :destination, :next_manifest)
      .order(Atua::Manifest.trip_at.desc, id: :desc).page(params[:page])
    @empty_legs_total = empty_legs.calculated.sum(:distance_km)
    load_expenses if can?(:read, :expenses)
  end

  private

  def load_expenses
    expenses = @vehicle.expenses.active

    @expenses = expenses.preload(:cost_object).order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
      .page(params[:expenses_page])
    @expenses_totals = expenses.total_by_allocation
  end
end
