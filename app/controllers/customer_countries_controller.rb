class CustomerCountriesController < BaseController
  before_action :set_customer

  def edit
    authorize!(:update, :customers)

    @customer_country_form = CustomerCountryForm.for_customer(@customer)
  end

  def update
    authorize!(:update, :customers)

    @customer_country_form = CustomerCountryForm.new(customer: @customer, **country_params)

    if @customer_country_form.save
      redirect_to customer_path(@customer), notice: t('.success')
    else
      flash.now[:alert] = @customer_country_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_customer
    @customer = current_tenant.atua_customers.active.find(params.expect(:customer_id))
  end

  def country_params
    params.expect(customer_country: %i[country_type]).to_h.symbolize_keys
  end
end
