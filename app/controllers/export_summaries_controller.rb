class ExportSummariesController < BaseController
  DETAIL_PARAM = 'detail'.freeze
  DOCUMENTS_PAGE_PARAM = :documents_page

  before_action :require_export_summary
  before_action :load_dashboard

  def show
    @detail_row = opened_detail_row
    @detail_documents = documents_page(@detail_row) if @detail_row
    @rows = listing_page(@dashboard.rows)

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.export_summary_xlsx_sheets(@dashboard) })
  end

  def documents
    @row = @dashboard.find_row(params[:key])
    return redirect_to(export_summary_path(filter_params), alert: t('.row_not_found')) unless @row

    respond_to do |format|
      format.turbo_stream { @documents = documents_page(@row) }
      format.html { redirect_to export_summary_path(filter_params.merge(DETAIL_PARAM => @row.key)) }
    end
  end

  private

  def require_export_summary
    raise ActionController::RoutingError, 'Not Found' unless ExportPlant.enabled?(current_tenant)
  end

  def load_dashboard
    authorize!(:read, :export_summary)

    @filter_form = ExportSummaryFilterForm.new(filter_params)
    return redirect_to(export_summary_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @dashboard = Dashboard::Export.new(documents: current_tenant.atua_transport_documents, manifests: current_tenant.atua_manifests,
                                       customers: current_tenant.atua_customers, plants: current_tenant.export_plants.activated,
                                       period: @filter_form.period, filters: @filter_form.dashboard_filters)
    @last_synced_at = current_tenant.last_synced_at
  end

  def opened_detail_row
    key = params[DETAIL_PARAM]

    @dashboard.find_row(key) if request.format.html? && key.present?
  end

  def documents_page(row)
    Kaminari.paginate_array(@dashboard.documents_for(row.key)).page(params[DOCUMENTS_PAGE_PARAM])
  end

  def filter_params
    params.permit(:start_date, :end_date, :customer_group_id, :plant, :country)
  end
end
