class RevenueProjectionHistoriesController < BaseController
  include FreightDocumentFilters

  CACHE_TTL = 1.hour

  before_action :require_revenue_projection

  def show
    authorize!(:read, :revenue_projection)

    @filter_form = RevenueProjectionHistoryFilterForm.new(filter_params)
    return redirect_to(revenue_projection_history_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    load_freight_filter_options
    @cut_items = cut_items
    @history = history

    respond_with_listing(pdf: false, xlsx: -> { helpers.revenue_projection_history_xlsx_sheets(@history, cut_items: @cut_items) })
  end

  def product_options
    authorize!(:read, :revenue_projection)

    load_product_options
    render 'product_options/show'
  end

  private

  def require_revenue_projection
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::RevenueProjection.enabled?(current_tenant)
  end

  def history
    return today_history if @filter_form.period_type == 'today'

    Dashboard::RevenueProjectionHistory.new(current_tenant, @filter_form.period_type, @filter_form.date_range, memory:)
  end

  def today_history
    Dashboard::RevenueProjectionToday.new(current_tenant, memory:, documents: filtered_freights(@filter_form.truck_group_id))
  end

  def memory
    return RevenueProjection::StoredMemory.new(current_tenant) unless @filter_form.cut?

    Rails.cache.fetch(replay_cache_key, expires_in: CACHE_TTL) do
      RevenueProjections::ReplayCommand.call(current_tenant, filtered_freights(@filter_form.truck_group_id), @filter_form.date_range)
    end
  end

  def replay_cache_key
    [
      :revenue_projection_replay, current_tenant.id, @filter_form.query_params.to_a, Date.current, current_tenant.last_synced_at || Time.current.beginning_of_hour,
      current_tenant.holidays.cache_key_with_version, current_tenant.excluded_issuers.cache_key_with_version, freight_truck_groups.cache_key_with_version
    ]
  end

  def cut_items
    @filter_form.cut_params.map { |attribute, value| [RevenueProjectionHistoryFilterForm.human_attribute_name(attribute), cut_value(attribute, value)] }
  end

  def cut_value(attribute, value)
    case attribute
    when :customer_group_id then @customer_groups.find_by(id: value)&.name
    when :product_group_id, :product_id then current_tenant.product_groups.find_by(id: value)&.name
    when :driver_code then @drivers.find { it.driver_code == value }&.driver_name
    when :macro_region_id then helpers.revenue_projection_history_macro_region_name(@macro_regions, value)
    when :truck_group_id then freight_truck_groups.find_by(id: value)&.name
    end || value.to_s.upcase
  end

  def filter_params
    params.permit(:start_date, :end_date, :period, :start, *FreightDocumentFilters::FILTER_PARAMS)
  end
end
