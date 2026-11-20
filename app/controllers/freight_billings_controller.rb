class FreightBillingsController < BaseController
  include FreightDocumentFilters

  DETAIL_PARAM = 'detail'.freeze

  before_action :load_dashboard, except: :product_options

  def show
    @detail_row = opened_detail_row
    load_freight_filter_options
    @last_synced_at = current_tenant.last_synced_at
    @rows = listing_page(@dashboard.sorted_rows(params[:sort], params[:direction]))

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.freight_billing_xlsx_sheets(@dashboard, @rows) })
  end

  def detail
    @row = @dashboard.row_for(params[:key])
    return redirect_to(freight_billing_path(filter_params), alert: t('.row_not_found')) unless @row

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to freight_billing_path(filter_params.merge(DETAIL_PARAM => @row.key)) }
    end
  end

  def freights
    @row = @dashboard.row_for(params[:key]) if @dashboard.lists_freights?(params[:key])
    return redirect_to(freight_billing_path(filter_params), alert: t('.row_not_found')) unless @row

    @freight_lines = @dashboard.freight_lines_for(@row.key, *freights_sort)
    respond_with_freights
  end

  def month
    @row = @dashboard.month_row(params[:month])
    return redirect_to(freight_billing_path(filter_params), alert: t('.month_not_found')) unless @row

    @freight_lines = @dashboard.history_freight_lines(@row.period, *freights_sort)
    respond_with_freights
  end

  def week
    @row = @dashboard.week_row(params[:week])
    return redirect_to(freight_billing_path(filter_params), alert: t('.week_not_found')) unless @row

    @freight_lines = @dashboard.history_freight_lines(@row.period, *freights_sort)
    respond_with_freights
  end

  def product_options
    authorize!(:read, :freight_billing)

    load_product_options
    render 'product_options/show'
  end

  private

  def freights_sort
    params.values_at(:freights_sort, :freights_direction)
  end

  def respond_with_freights
    respond_to do |format|
      format.turbo_stream
      format.html { render partial: 'freights_table', locals: { row: @row, freight_lines: @freight_lines } }
    end
  end

  def opened_detail_row
    key = request.query_parameters.delete(DETAIL_PARAM)

    @dashboard.row_for(key) if request.format.html? && !key.nil?
  end

  def load_dashboard
    authorize!(:read, :freight_billing)

    @filter_form = FreightBillingFilterForm.new(filter_params)
    return redirect_to(freight_billing_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @truck_groups = freight_truck_groups
    @dashboard = Dashboard::Freight.new(filtered_freights(@filter_form.truck_group_id),
                                        manifests: current_tenant.atua_manifests,
                                        dimension: @filter_form.dimension,
                                        period: @filter_form.period,
                                        own_fleet: current_tenant.own_fleet,
                                        comparison: Dashboard::Freight.comparison_enabled?(current_tenant))
  end

  def filter_params
    params.permit(:start_date, :end_date, :dimension, *FreightDocumentFilters::FILTER_PARAMS)
  end
end
