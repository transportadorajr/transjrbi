class CustomerGroupAssignmentsController < BaseController
  before_action :set_customer

  def edit
    authorize!(:update, :customers)

    @customer_group_assignment_form = CustomerGroupAssignmentForm.for_customer(@customer)
  end

  def update
    authorize!(:update, :customers)

    @customer_group_assignment_form = CustomerGroupAssignmentForm.new(customer: @customer, **customer_group_params)

    if @customer_group_assignment_form.save
      redirect_to customer_path(@customer), notice: t('.success')
    else
      flash.now[:alert] = @customer_group_assignment_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_customer
    @customer = current_tenant.atua_customers.active.preload(:customer_group).find(params.expect(:customer_id))
  end

  def customer_group_params
    params.expect(customer_group_assignment: %i[customer_group_id]).to_h.symbolize_keys
  end
end
