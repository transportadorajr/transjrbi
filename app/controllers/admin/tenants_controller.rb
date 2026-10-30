module Admin
  class TenantsController < BaseController
    has_scope :by_name, as: :name

    before_action :set_tenant, only: %i[edit update]

    def index
      @tenants = apply_sort(apply_scopes(Tenant.preload(:owner)), :name, :id).page(params[:page])
    end

    def new
      @tenant_form = Admin::TenantForm.new
    end

    def edit
      @tenant_form = Admin::TenantForm.for_tenant(@tenant)
    end

    def create
      @tenant_form = Admin::TenantForm.new(tenant_params)

      if @tenant_form.save
        redirect_to admin_tenants_path, notice: t('.success')
      else
        flash.now[:alert] = @tenant_form.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def update
      @tenant_form = Admin::TenantForm.for_tenant(@tenant)
      @tenant_form.assign_attributes(tenant_params)

      if @tenant_form.save
        redirect_to admin_tenants_path, notice: t('.success')
      else
        flash.now[:alert] = @tenant_form.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_tenant
      @tenant = Tenant.find(params.expect(:id))
    end

    def tenant_params
      params.expect(admin_tenant: %i[name trade_name legal_id atua_url atua_device_token atua_device_hash
                                     owner_name owner_email owner_password owner_password_confirmation])
    end
  end
end
