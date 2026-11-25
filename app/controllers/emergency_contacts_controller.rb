class EmergencyContactsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type
  has_scope :by_emergency_contact, as: :contact

  before_action :set_employee, only: %i[new create]
  before_action :set_emergency_contact, only: %i[edit update destroy]

  def index
    authorize!(:read, :emergency_contacts)

    employees = current_tenant.employees.activated.preload(:emergency_contacts)
    @employees = listing_page(apply_sort(apply_scopes(employees), :name, :id))
  end

  def new
    authorize!(:create, :emergency_contacts)

    @emergency_contact_form = EmergencyContactForm.for_employee(@employee)
  end

  def edit
    authorize!(:update, :emergency_contacts)

    @emergency_contact_form = EmergencyContactForm.for_emergency_contact(@emergency_contact)
  end

  def create
    authorize!(:create, :emergency_contacts)

    @emergency_contact_form = EmergencyContactForm.new(employee: @employee, **emergency_contact_params)

    if @emergency_contact_form.save
      redirect_to employee_path(@employee, anchor: 'emergency_contacts'), notice: t('.success')
    else
      flash.now[:alert] = @emergency_contact_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :emergency_contacts)

    @emergency_contact_form = EmergencyContactForm.for_emergency_contact(@emergency_contact)
    @emergency_contact_form.assign_attributes(emergency_contact_params)

    if @emergency_contact_form.save
      redirect_to employee_path(@emergency_contact.employee, anchor: 'emergency_contacts'), notice: t('.success')
    else
      flash.now[:alert] = @emergency_contact_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :emergency_contacts)

    @emergency_contact.destroy!
    redirect_to employee_path(@emergency_contact.employee, anchor: 'emergency_contacts'), notice: t('.success'), status: :see_other
  end

  private

  def set_employee
    @employee = current_tenant.employees.find(params.expect(:employee_id))
  end

  def set_emergency_contact
    @emergency_contact = current_tenant.emergency_contacts.preload(:employee).find(params.expect(:id))
  end

  def emergency_contact_params
    params.expect(emergency_contact: %i[name relationship_type phone secondary_phone position notes]).to_h.symbolize_keys
  end
end
