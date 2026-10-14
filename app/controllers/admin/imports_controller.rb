module Admin
  class ImportsController < BaseController
    has_scope :by_tenant, as: :tenant_id
    has_scope :by_report_type, as: :report_type
    has_scope :by_status_type, as: :status
    has_scope :by_period_start, as: :start_date
    has_scope :by_period_end, as: :end_date

    before_action :set_import, only: %i[download reprocess]
    before_action :set_tenants, only: %i[index new create]

    def index
      counted_imports = apply_scopes(Atua::Import.all, params.except(:status))

      @imports = apply_scopes(Atua::Import.all).preload(:tenant, :file_attachment).order(created_at: :desc, id: :desc).page(params[:page])
      @total_count = counted_imports.count
      @succeeded_count = counted_imports.succeeded.count
      @failed_count = counted_imports.failed.count
      @running_count = counted_imports.running.count
      @action_required_imports = Atua::Import.latest_per_report.requiring_action.preload(:tenant).order(:finished_at)
      @tenant_statuses = Atua::ImportOverview.new(@tenants).statuses
    end

    def new
      today = Time.zone.today

      @import_form = Admin::ImportForm.new(tenant_id: params[:tenant_id], start_date: today.beginning_of_month, end_date: today)
    end

    def create
      @import_form = Admin::ImportForm.new(import_params)

      if @import_form.save
        redirect_to admin_imports_path, notice: t('.success')
      else
        flash.now[:alert] = @import_form.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def download
      send_data @import.file.download, filename: @import.file.filename.to_s, content_type: @import.file.content_type, disposition: :attachment
    end

    def reprocess
      if @import.validate_reprocess
        redirect_to admin_imports_path, notice: t('.success')
      else
        redirect_to admin_imports_path, alert: @import.errors.full_messages.to_sentence
      end
    end

    private

    def set_import
      @import = Atua::Import.find(params.expect(:id))
    end

    def set_tenants
      @tenants = Tenant.order(:trade_name)
    end

    def import_params
      params.expect(admin_import: %i[tenant_id report_type start_date end_date])
    end
  end
end
