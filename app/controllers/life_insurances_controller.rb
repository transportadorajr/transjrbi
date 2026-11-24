class LifeInsurancesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :life_insurances)

    life_insurances = apply_scopes(
      current_tenant.life_insurances.covered_on(Date.current).joins(:employee, :life_insurance_policy).preload(:employee, :life_insurance_policy),
    )
    @premium_totals = life_insurances.premium_totals
    @uninsured_count = apply_scopes(current_tenant.employees.without_life_insurance).count
    @life_insurances = listing_page(apply_sort(life_insurances, Employee.arel_table[:name].asc, id: :asc))

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.life_insurances_xlsx_sheets(@life_insurances) })
  end
end
