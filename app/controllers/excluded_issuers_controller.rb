class ExcludedIssuersController < BaseController
  has_scope :by_name, as: :name

  def index
    authorize!(:read, :excluded_issuers)

    @excluded_issuers = apply_scopes(current_tenant.excluded_issuers).with_document_totals.order(:name, :id).page(params[:page])
  end

  def new
    authorize!(:create, :excluded_issuers)

    @excluded_issuer_form = ExcludedIssuerForm.new(tenant: current_tenant)
  end

  def create
    authorize!(:create, :excluded_issuers)

    @excluded_issuer_form = ExcludedIssuerForm.new(tenant: current_tenant, **excluded_issuer_params)

    if @excluded_issuer_form.save
      redirect_to excluded_issuers_path, notice: t('.success')
    else
      flash.now[:alert] = @excluded_issuer_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :excluded_issuers)

    current_tenant.excluded_issuers.find(params.expect(:id)).destroy!
    redirect_to excluded_issuers_path, notice: t('.success')
  end

  private

  def excluded_issuer_params
    params.expect(excluded_issuer: [:code])
  end
end
