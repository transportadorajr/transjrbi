class ProductGroupsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :set_product_group, only: %i[show edit update destroy]

  def index
    authorize!(:read, :product_groups)

    product_groups = current_tenant.product_groups.groups
    counted_product_groups = apply_scopes(product_groups, params.except(:status))

    @product_groups = apply_sort(apply_scopes(product_groups), :name, :id).page(params[:page])
    @subgroup_counts = current_tenant.product_groups.where(parent_id: @product_groups.map(&:id)).group(:parent_id).count
    @document_counts = documents.joins(:product_group).where(product_groups: { parent_id: @product_groups.map(&:id) })
      .group(ProductGroup.arel_table[:parent_id]).count
    @total_count = counted_product_groups.count
    @active_count = counted_product_groups.activated.count
    @deactivated_count = counted_product_groups.not_activated.count
    @unclassified_products = product_name_counts(documents.where(product_group_id: nil))
  end

  def show
    authorize!(:read, :product_groups)

    if @product_group.group?
      @subgroups = apply_sort(@product_group.subgroups, :name, :id).page(params[:page])
      @document_counts = documents.where(product_group_id: @subgroups.map(&:id)).group(:product_group_id).count
      @documents_count = documents.where(product_group_id: @product_group.subgroups.select(:id)).count
    else
      @products = product_name_counts(documents.where(product_group_id: @product_group.id))
      @documents_count = @products.sum(&:last)
    end
  end

  def new
    authorize!(:create, :product_groups)

    parent = current_tenant.product_groups.groups.find(params.expect(:parent_id)) if params.key?(:parent_id)
    @product_group_form = ProductGroupForm.new(tenant: current_tenant, parent_id: parent&.id)
  end

  def edit
    authorize!(:update, :product_groups)

    @product_group_form = ProductGroupForm.for_product_group(@product_group)
  end

  def create
    authorize!(:create, :product_groups)

    @product_group_form = ProductGroupForm.new(tenant: current_tenant, **create_params)

    if @product_group_form.save
      redirect_to product_group_path(@product_group_form.parent || @product_group_form.product_group), notice: t('.success')
    else
      flash.now[:alert] = @product_group_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :product_groups)

    @product_group_form = ProductGroupForm.for_product_group(@product_group)
    @product_group_form.assign_attributes(update_params)

    if @product_group_form.save
      redirect_to product_group_path(@product_group), notice: t('.success')
    else
      flash.now[:alert] = @product_group_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :product_groups)

    path = @product_group.parent ? product_group_path(@product_group.parent) : product_groups_path

    if @product_group.destroy
      redirect_to path, notice: t('.success')
    else
      redirect_to path, alert: @product_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_product_group
    @product_group = current_tenant.product_groups.find(params.expect(:id))
  end

  def documents
    current_tenant.atua_transport_documents.active.freights
  end

  def product_name_counts(relation)
    relation.where.not(product_name: nil).group(:product_name).count.sort_by { |product_name, count| [-count, product_name] }
  end

  def create_params
    params.expect(product_group: [:name, :parent_id, :active, { product_names: [] }])
  end

  def update_params
    params.expect(product_group: [:name, :active, { product_names: [] }])
  end
end
