class InsuranceRatesController < BaseController
  def show
    authorize!(:read, :insurance_rates)

    @insurance_rate = InsuranceRate.find_by(tenant: current_tenant)
    insurance_expenses = current_tenant.freight_expenses.insurance
    @expenses_count = insurance_expenses.count
    @expenses_total = Money.from_cents(insurance_expenses.sum(:amount_cents))
  end

  def edit
    authorize!(:update, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.for_tenant(current_tenant)
  end

  def update
    authorize!(:update, :insurance_rates)

    @insurance_rate_form = InsuranceRateForm.for_tenant(current_tenant)
    @insurance_rate_form.assign_attributes(insurance_rate_params)

    if @insurance_rate_form.save
      redirect_to insurance_rate_path, notice: t('.success')
    else
      flash.now[:alert] = @insurance_rate_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def insurance_rate_params
    params.expect(insurance_rate: %i[insurance_percentage iof_percentage])
  end
end
