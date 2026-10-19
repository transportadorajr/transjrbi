module Admin
  class HttpRequestsController < BaseController
    has_scope :by_integration_type, as: :integration_type
    has_scope :by_status_group, as: :status
    has_scope :by_tenant, as: :tenant_id
    has_scope :by_atua_import, as: :atua_import_id
    has_scope :by_url, as: :url
    has_scope :by_period_start, as: :start_date
    has_scope :by_period_end, as: :end_date

    def index
      counted_requests = apply_scopes(Admin::HttpRequest.all, params.except(:status))

      @http_requests = apply_scopes(Admin::HttpRequest.all).preload(:tenant).order(created_at: :desc, id: :desc).page(params[:page])
      @total_count = counted_requests.count
      @succeeded_count = counted_requests.succeeded.count
      @failed_count = counted_requests.failed.count
      @tenants = Tenant.order(:trade_name)
    end

    def show
      @http_request = Admin::HttpRequest.preload(:tenant, :atua_import).find(params.expect(:id))
      @chain = @http_request.chain
    end
  end
end
