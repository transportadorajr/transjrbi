module FreightDocumentFilters
  extend ActiveSupport::Concern

  FILTER_PARAMS = %i[plate driver_code customer_group_id product_group_id product_id macro_region_id truck_group_id].freeze

  included do
    include ProductOptions

    has_scope :by_plate, as: :plate
    has_scope :by_driver, as: :driver_code
    has_scope :by_customer_group, as: :customer_group_id
    has_scope :by_product_group, as: :product_group_id
    has_scope :by_product, as: :product_id
    has_scope :by_origin_macro_region, as: :macro_region_id
  end

  private

  def load_freight_filter_options
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
    @product_groups = current_tenant.product_groups.groups.activated.order(:name)
    load_product_options
    @macro_regions = current_tenant.macro_regions.order(:name)
    @truck_groups = freight_truck_groups
  end

  def freight_truck_groups
    @freight_truck_groups ||= current_tenant.truck_groups.activated.where(remaining_axles: false).order(:name)
  end

  def filtered_freights(truck_group_id)
    documents = apply_scopes(current_tenant.billable_freights)
    return documents if truck_group_id.blank?

    truck_group = freight_truck_groups.find_by(id: truck_group_id)
    truck_group ? documents.by_truck_group(truck_group, freight_truck_groups.flat_map(&:plates)) : documents.none
  end
end
