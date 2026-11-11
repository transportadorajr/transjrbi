class FreightBillingsController < BaseController
  include ProductOptions

  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_product_group, as: :product_group_id
  has_scope :by_product, as: :product_id
  has_scope :by_origin_macro_region, as: :macro_region_id

  DETAIL_PARAM = 'detail'.freeze

  before_action :load_dashboard, except: :product_options

  def show
    @detail_row = opened_detail_row
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
    @product_groups = current_tenant.product_groups.groups.activated.order(:name)
    load_product_options
    @macro_regions = current_tenant.macro_regions.order(:name)
    @last_synced_at = current_tenant.last_synced_at
    @rows = listing_page(@dashboard.sorted_rows(params[:sort], params[:direction]))

    respond_with_listing(orientation: :landscape)
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

    @transport_documents = @dashboard.freights_for(@row.key)
  end

  def month
    @row = @dashboard.month_row(params[:month])
    return redirect_to(freight_billing_path(filter_params), alert: t('.month_not_found')) unless @row

    @transport_documents = @dashboard.history_freights(@row.period)
  end

  def week
    @row = @dashboard.week_row(params[:week])
    return redirect_to(freight_billing_path(filter_params), alert: t('.week_not_found')) unless @row

    @transport_documents = @dashboard.history_freights(@row.period)
  end

  def product_options
    authorize!(:read, :freight_billing)

    load_product_options
    render 'product_options/show'
  end

  private

  def opened_detail_row
    key = request.query_parameters.delete(DETAIL_PARAM)

    @dashboard.row_for(key) if request.format.html? && !key.nil?
  end

  def load_dashboard
    authorize!(:read, :freight_billing)

    @filter_form = FreightBillingFilterForm.new(filter_params)
    return redirect_to(freight_billing_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @truck_groups = current_tenant.truck_groups.activated.where(remaining_axles: false).order(:name)
    @dashboard = Dashboard::Freight.new(documents,
                                        manifests: current_tenant.atua_manifests,
                                        dimension: @filter_form.dimension,
                                        period: @filter_form.period)
  end

  def documents
    documents = apply_scopes(current_tenant.billable_freights)
    truck_group_id = @filter_form.truck_group_id
    return documents if truck_group_id.blank?

    truck_group = @truck_groups.find_by(id: truck_group_id)
    truck_group ? documents.by_truck_group(truck_group, @truck_groups.flat_map(&:plates)) : documents.none
  end

  def filter_params
    params.permit(:start_date, :end_date, :dimension, :plate, :driver_code, :customer_group_id, :product_group_id, :product_id, :macro_region_id,
                  :truck_group_id)
  end
end
