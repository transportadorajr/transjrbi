class CustomersController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_document, as: :document
  has_scope :by_city, as: :city

  def index
    authorize!(:read, :customers)

    @customers = apply_scopes(current_tenant.atua_customers.active).order(:name, :id).page(params[:page])
  end

  def show
    authorize!(:read, :customers)

    @customer = current_tenant.atua_customers.active.find(params.expect(:id))
  end
end
