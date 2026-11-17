module MaintenanceCatalog
  extend ActiveSupport::Concern

  included do
    include MaintenanceFeature

    has_scope :by_term, as: :term
    has_scope :by_status, as: :status

    before_action :set_item, only: %i[edit update]
  end

  def index
    authorize!(:read, catalog_resource)

    @items = listing_page(apply_sort(apply_scopes(catalog_scope), :description, :id))
  end

  def new
    authorize!(:create, catalog_resource)

    @item_form = catalog_form_class.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, catalog_resource)

    @item_form = catalog_form_class.for_item(@item)
  end

  def create
    authorize!(:create, catalog_resource)

    @item_form = catalog_form_class.new(tenant: current_tenant, **item_params)
    save_item_form(:new)
  end

  def update
    authorize!(:update, catalog_resource)

    @item_form = catalog_form_class.for_item(@item)
    @item_form.assign_attributes(item_params)
    save_item_form(:edit)
  end

  private

  def save_item_form(failure_template)
    if @item_form.save
      redirect_to url_for(action: :index), notice: t('.success')
    else
      flash.now[:alert] = @item_form.errors.full_messages.to_sentence
      render failure_template, status: :unprocessable_content
    end
  end

  def catalog_resource
    controller_name.to_sym
  end

  def set_item
    @item = catalog_scope.find(params.expect(:id))
  end

  def item_params
    params.expect(catalog_form_class.model_name.param_key => catalog_form_class::PERMITTED_ATTRIBUTES)
  end
end
