class RevenueGoalsController < BaseController
  before_action :require_revenue_goals
  before_action :load_filter_form, only: %i[show edit replicate]

  def show
    authorize!(:read, :revenue_goals)

    @revenue_goals_form = RevenueGoalsForm.for_month(current_tenant, @month)
  end

  def edit
    authorize!(:update, :revenue_goals)

    @revenue_goals_form = RevenueGoalsForm.for_month(current_tenant, @month)
  end

  def update
    authorize!(:update, :revenue_goals)

    @revenue_goals_form = RevenueGoalsForm.new(tenant: current_tenant)
    @revenue_goals_form.assign_attributes(revenue_goals_params)

    if @revenue_goals_form.save
      redirect_to revenue_goals_path(month: @revenue_goals_form.month), notice: t('.success')
    else
      @month = @revenue_goals_form.month_value || Date.current.beginning_of_month
      flash.now[:alert] = @revenue_goals_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def replicate
    authorize!(:update, :revenue_goals)

    copied = RevenueGoals::ReplicateMonthCommand.call(current_tenant, @month)
    redirect_to revenue_goals_path(month: @month.strftime(RevenueGoal::MONTH_FORMAT)), notice: t('.success', count: copied.size)
  end

  private

  def require_revenue_goals
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::Goals.enabled?(current_tenant)
  end

  def load_filter_form
    filter_form = GoalFilterForm.new(month: params[:month])
    return redirect_to(revenue_goals_path, alert: filter_form.errors.full_messages.to_sentence) if filter_form.invalid?

    @month = filter_form.month_value
  end

  def revenue_goals_params
    params.expect(revenue_goals: [:month, :company, { vehicles_attributes: [%i[plate amount]] }])
  end
end
