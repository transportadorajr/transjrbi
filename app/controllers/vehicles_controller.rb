class VehiclesController < BaseController
  include ReturnPath

  has_scope :by_plate, as: :plate
  has_scope :by_category, as: :category
  has_scope :by_ownership, as: :ownership

  def index
    authorize!(:read, :vehicles)

    vehicles = current_tenant.atua_vehicles.active.with_transport_documents_in(Time.current.all_year)

    @vehicles = listing_page(apply_sort(apply_scopes(vehicles), :plate, :id))
    @categories = vehicles.where.not(category: nil).distinct.order(:category).pluck(:category)
    @ownerships = vehicles.where.not(ownership: nil).distinct.order(:ownership).pluck(:ownership)
    @year = Date.current.year

    respond_with_listing(orientation: :landscape, xlsx: @vehicles)
  end

  def show
    authorize!(:read, :vehicles)

    @vehicle = current_tenant.atua_vehicles.active.find(params.expect(:id))
    return redirect_to(vehicle_path(@vehicle, request.query_parameters.merge(return_to: referer_return_path))) if return_to_from_referer?

    empty_legs = current_tenant.empty_legs.where(plate: @vehicle.plate)
    @empty_legs = empty_legs.left_joins(:next_manifest, :next_transport_document)
      .where(Atua::Manifest.arel_table[:id].not_eq(nil).or(Atua::TransportDocument.arel_table[:id].not_eq(nil)))
      .preload(:origin, :destination, :next_manifest, :next_transport_document)
      .order(EmptyLeg.trip_at.desc, id: :desc).page(params[:page])
    @empty_legs_total = empty_legs.calculated.sum(:distance_km)
    load_expenses if can?(:read, :expenses)
  end

  private

  def return_to_from_referer?
    params[:return_to].blank? && referer_return_path.present?
  end

  def load_expenses
    expenses = @vehicle.expenses.active

    @expenses = expenses.preload(:cost_object).order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
      .page(params[:expenses_page])
    @expenses_totals = expenses.total_by_allocation
  end
end
