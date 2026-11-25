class LifeInsuranceMovementsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :life_insurances)

    @month = LifeInsuranceMovement.month_dates(params[:month]).first
    movements = LifeInsuranceMovement.for_month(apply_scopes(current_tenant.life_insurances), params[:month])
    @kind_counts = LifeInsuranceMovement::KINDS.keys.index_with { |kind| movements.count { |movement| movement.kind == kind } }
    @movements = listing_page(movements)

    respond_with_listing(pdf: false, xlsx: -> { helpers.life_insurance_movements_xlsx_sheets(@movements) })
  end
end
