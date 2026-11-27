class EmptyLegsController < BaseController
  has_scope :by_trip_start, as: :start_date, default: -> { Date.current.beginning_of_month.iso8601 }
  has_scope :by_trip_end, as: :end_date
  has_scope :by_plate, as: :plate
  has_scope :by_loading_macro_region, as: :macro_region_id
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_min_distance, as: :min_distance

  def index
    authorize!(:read, :empty_legs)

    filtered = apply_scopes(current_tenant.empty_legs.joins(:next_manifest))
    legs = filtered.calculated.with_loading_macro_region.preload(:origin, :destination, :next_manifest)

    @dashboard = Dashboard::EmptyLegs.new(filtered)
    @empty_legs = listing_page(apply_sort(legs, EmptyLeg.arel_table[:distance_km].desc, id: :desc))
    @regions = listing_page(@dashboard.regions, param_name: :regions_page)
    @start_date = params.fetch(:start_date, Date.current.beginning_of_month.iso8601)
    load_filter_options

    respond_with_listing(pdf: false, xlsx: -> { Export::Sheet.for(@empty_legs, name: t('.title'), except: EmptyLeg::EXPORT_EXCEPTIONS) })
  end

  private

  def load_filter_options
    @macro_regions = current_tenant.macro_regions.order(:state, :name)
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
  end
end
