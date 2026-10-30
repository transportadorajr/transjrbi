class CustomersController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_document, as: :document
  has_scope :by_city, as: :city
  has_scope :by_customer_group, as: :customer_group

  def index
    authorize!(:read, :customers)

    @customers = apply_sort(apply_scopes(current_tenant.atua_customers.active).preload(:customer_group), :name, :id).page(params[:page])
    @customer_groups = current_tenant.customer_groups.order(:name)
  end

  def show
    authorize!(:read, :customers)

    @customer = current_tenant.atua_customers.active.preload(:customer_group).find(params.expect(:id))
  end
end
