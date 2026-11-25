class HrPendenciesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :hr_pendencies)

    @dashboard = Dashboard::HrPendencies.new(tenant: current_tenant, kinds: Dashboard::HrPendencies.kinds_for(current_ability))
    rows = @dashboard.rows(apply_sort(apply_scopes(current_tenant.employees), :name, :id))
    @counts = @dashboard.counts(rows)
    @rows = listing_page(@dashboard.with_kind(rows, params[:pendency]))
  end
end
