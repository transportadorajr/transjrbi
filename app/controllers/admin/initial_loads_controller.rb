module Admin
  class InitialLoadsController < BaseController
    before_action :set_tenants

    def new
      @initial_load_form = Admin::InitialLoadForm.with_default_period(tenant_id: params[:tenant_id])
    end

    def create
      @initial_load_form = Admin::InitialLoadForm.new(initial_load_params)

      if @initial_load_form.save
        redirect_to admin_imports_path, notice: t('.success', tenant: @initial_load_form.tenant.trade_name)
      else
        flash.now[:alert] = @initial_load_form.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    private

    def set_tenants
      @tenants = Tenant.order(:trade_name)
    end

    def initial_load_params
      params.expect(admin_initial_load: %i[tenant_id start_date end_date])
    end
  end
end
