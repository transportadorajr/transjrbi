module ProductOptions
  private

  def load_product_options
    products = current_tenant.product_groups.classifying.preload(:parent).order(:name, :id)
    products = products.where(parent_id: params[:product_group_id]) if params[:product_group_id].present?

    @products = products
    @selected_product_id = params[:product_id] if params[:product_id].present? && products.exists?(id: params[:product_id])
  end
end
