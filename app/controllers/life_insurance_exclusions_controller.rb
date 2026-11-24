class LifeInsuranceExclusionsController < BaseController
  before_action :set_life_insurance

  def new
    authorize!(:update, :life_insurances)

    @life_insurance_exclusion_form = LifeInsuranceExclusionForm.new(life_insurance: @life_insurance)
  end

  def create
    authorize!(:update, :life_insurances)

    @life_insurance_exclusion_form = LifeInsuranceExclusionForm.new(life_insurance: @life_insurance, **exclusion_params)

    if @life_insurance_exclusion_form.save
      redirect_to life_insurances_path, notice: t('.success')
    else
      flash.now[:alert] = @life_insurance_exclusion_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_life_insurance
    @life_insurance = current_tenant.life_insurances.where(excluded_on: nil).preload(:employee).find(params.expect(:life_insurance_id))
  end

  def exclusion_params
    params.expect(life_insurance_exclusion: %i[excluded_on]).to_h.symbolize_keys
  end
end
