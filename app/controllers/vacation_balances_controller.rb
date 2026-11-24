class VacationBalancesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :vacations)

    balances = Dashboard::VacationBalances.new
    periods = balances.periods(apply_scopes(current_tenant.employees))
    @counts = balances.counts(periods)
    @periods = listing_page(balances.with_status(periods, params[:status]))
  end
end
