class CompaniesController < BaseController
  def show
    authorize!(:read, :company)

    @company = current_tenant
  end

  def edit
    authorize!(:update, :company)

    @company_form = CompanyForm.for_tenant(current_tenant)
  end

  def update
    authorize!(:update, :company)

    @company_form = CompanyForm.for_tenant(current_tenant)
    @company_form.assign_attributes(company_params)

    if @company_form.save
      redirect_to company_path, notice: t('.success')
    else
      flash.now[:alert] = @company_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def company_params
    params.expect(company: %i[name trade_name legal_id atua_url atua_device_token atua_device_hash])
  end
end
