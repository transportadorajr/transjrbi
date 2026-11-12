class SuppliersController < BaseController
  include MaintenanceFeature

  has_scope :by_name, as: :name

  before_action :set_supplier, only: %i[edit update]

  def index
    authorize!(:read, :suppliers)

    @suppliers = listing_page(apply_sort(apply_scopes(current_tenant.suppliers), :name, :id))
  end

  def new
    authorize!(:create, :suppliers)

    @supplier_form = SupplierForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :suppliers)

    @supplier_form = SupplierForm.for_supplier(@supplier)
  end

  def create
    authorize!(:create, :suppliers)

    @supplier_form = SupplierForm.new(tenant: current_tenant, **supplier_params)

    if @supplier_form.save
      redirect_to suppliers_path, notice: t('.success')
    else
      flash.now[:alert] = @supplier_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :suppliers)

    @supplier_form = SupplierForm.for_supplier(@supplier)
    @supplier_form.assign_attributes(supplier_params)

    if @supplier_form.save
      redirect_to suppliers_path, notice: t('.success')
    else
      flash.now[:alert] = @supplier_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_supplier
    @supplier = current_tenant.suppliers.find(params.expect(:id))
  end

  def supplier_params
    params.expect(supplier: %i[name document active])
  end
end
