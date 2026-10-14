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
  end
end
