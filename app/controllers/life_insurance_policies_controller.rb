class LifeInsurancePoliciesController < BaseController
  before_action :set_life_insurance_policy, only: %i[edit update]

  def index
    authorize!(:read, :life_insurances)

    @life_insurance_policies = listing_page(current_tenant.life_insurance_policies.order(:company_type, :id))
    @available_company_types = LifeInsurancePolicyForm.new(tenant: current_tenant).available_company_types
  end

  def new
    authorize!(:create, :life_insurances)

    @life_insurance_policy_form = LifeInsurancePolicyForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :life_insurances)

    @life_insurance_policy_form = LifeInsurancePolicyForm.for_life_insurance_policy(@life_insurance_policy)
  end

  def create
    authorize!(:create, :life_insurances)

    @life_insurance_policy_form = LifeInsurancePolicyForm.new(tenant: current_tenant, **life_insurance_policy_params)

    if @life_insurance_policy_form.save
      redirect_to life_insurance_policies_path, notice: t('.success')
    else
      flash.now[:alert] = @life_insurance_policy_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :life_insurances)

    @life_insurance_policy_form = LifeInsurancePolicyForm.for_life_insurance_policy(@life_insurance_policy)
    @life_insurance_policy_form.assign_attributes(life_insurance_policy_params.except(:company_type))

    if @life_insurance_policy_form.save
      redirect_to life_insurance_policies_path, notice: t('.success')
    else
      flash.now[:alert] = @life_insurance_policy_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_life_insurance_policy
    @life_insurance_policy = current_tenant.life_insurance_policies.find(params.expect(:id))
  end

  def life_insurance_policy_params
    params.expect(life_insurance_policy: %i[company_type capital premium_rate_per_mille spouse_percentage children_percentage funeral_assistance])
      .to_h.symbolize_keys
  end
end
