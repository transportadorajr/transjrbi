class AbsencesController < BaseController
  def index
    authorize!(:read, :vacations)

    @calendar = Dashboard::Absences.new(tenant: current_tenant, month: params[:month])
    @absences = listing_page(@calendar.absences)
  end
end
