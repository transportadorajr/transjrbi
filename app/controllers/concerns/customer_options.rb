module CustomerOptions
  private

  def load_customer_options
    customers = current_tenant.atua_customers.active.order(:name, :id)
    customers = customers.by_customer_group(params[:customer_group_id]) if params[:customer_group_id].present?

    @customers = customers.select(:code, :name, :document)
    @selected_customer_code = params[:customer_code] if params[:customer_code].present? && customers.exists?(code: params[:customer_code])
  end
end
