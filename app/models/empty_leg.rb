class EmptyLeg < ApplicationRecord
  include Sortable
  include Exportable

  STATUSES = %i[calculated unlocated unrouted].freeze
  EXPORT_EXCEPTIONS = %w[next_manifest_code previous_manifest_code next_transport_document_code previous_transport_document_code
                         status_type calculated_at created_at updated_at].freeze
  LOADING_DOCUMENT_FROM = <<~SQL.squish.freeze
    FROM empty_leg_transport_documents links
    JOIN atua_transport_documents documents ON documents.tenant_id = links.tenant_id AND documents.code = links.transport_document_code
    LEFT JOIN macro_regions ON macro_regions.id = documents.origin_macro_region_id
    WHERE links.empty_leg_id = empty_legs.id
    ORDER BY links.id
    LIMIT 1
  SQL

  belongs_to :tenant
  belongs_to :origin, class_name: 'Location', optional: true
  belongs_to :destination, class_name: 'Location', optional: true
  belongs_to :road_route, optional: true
  has_many :empty_leg_transport_documents, dependent: :delete_all
  has_many :transport_documents, through: :empty_leg_transport_documents
  with_options class_name: 'Atua::Manifest', primary_key: %i[tenant_id code], optional: true do
    belongs_to :previous_manifest, foreign_key: %i[tenant_id previous_manifest_code], inverse_of: false
    belongs_to :next_manifest, foreign_key: %i[tenant_id next_manifest_code], inverse_of: :empty_leg
  end

  enum :status_type, STATUSES.index_with(&:to_s), validate: true
  enum :precision_type, Location::PRECISIONS.index_with(&:to_s), prefix: :precision, validate: { allow_nil: true }

  export_field(:trip_on, :date) { |empty_leg| empty_leg.next_manifest&.trip_on }
  export_field(:next_manifest) { |empty_leg| empty_leg.next_manifest&.number }
  export_field(:origin) { |empty_leg| empty_leg.origin && [empty_leg.origin.city, empty_leg.origin.state].join('/') }
  export_field(:destination) { |empty_leg| empty_leg.destination && [empty_leg.destination.city, empty_leg.destination.state].join('/') }
  export_field(:loading_macro_region) { |empty_leg| empty_leg[:loading_macro_region_name] }

  sortable :plate
  sortable :distance_km, -> { arel_table[:distance_km] }
  sortable :trip_on, -> { Atua::Manifest.trip_at }

  validates :plate, :previous_manifest_code, :next_manifest_code, :calculated_at, presence: true
  validates :next_manifest_code, uniqueness: { scope: :tenant_id }
  validates :distance_km, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :calculated?

  scope :by_trip_start, ->(date) { joins(:next_manifest).where(trip_on.gteq(date.to_date)) }
  scope :by_trip_end, ->(date) { joins(:next_manifest).where(trip_on.lteq(date.to_date)) }
  scope :by_plate, ->(plate) { where(plate: Atua::Manifest.normalize_plate(plate)) }
  scope :by_min_distance, ->(distance_km) { where(distance_km: distance_km.to_d..) }
  scope :by_loading_macro_region, ->(macro_region_id) {
    where(loading_macro_region_id.eq(macro_region_id.to_s == MacroRegion::OTHERS ? nil : macro_region_id.to_i))
  }
  scope :by_customer_group, ->(customer_group_id) {
    links = EmptyLegTransportDocument.arel_table

    where(EmptyLegTransportDocument.joins(:transport_document).merge(Atua::TransportDocument.by_customer_group(customer_group_id))
      .where(links[:empty_leg_id].eq(arel_table[:id])).arel.exists)
  }
  scope :with_loading_macro_region, -> { select(arel_table[Arel.star], loading_macro_region_name.as('loading_macro_region_name')) }

  class << self
    def trip_on
      Arel.sql(Atua::Manifest.trip_on_sql)
    end

    def loading_macro_region_id
      Arel.sql("(SELECT documents.origin_macro_region_id #{LOADING_DOCUMENT_FROM})")
    end

    def loading_macro_region_name
      Arel.sql("(SELECT macro_regions.name #{LOADING_DOCUMENT_FROM})")
    end
  end
end

# == Schema Information
#
# Table name: empty_legs
#
#  id                               :bigint           not null, primary key
#  calculated_at                    :datetime         not null
#  distance_km                      :decimal(14, 2)
#  next_manifest_code               :bigint
#  next_transport_document_code     :bigint
#  plate                            :string           not null
#  precision_type                   :enum
#  previous_manifest_code           :bigint
#  previous_transport_document_code :bigint
#  status_type                      :enum             not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  destination_id                   :bigint
#  origin_id                        :bigint
#  road_route_id                    :bigint
#  tenant_id                        :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_previous_transport_document_code_d369482e16    (tenant_id,previous_transport_document_code)
#  index_empty_legs_on_destination_id                              (destination_id)
#  index_empty_legs_on_origin_id                                   (origin_id)
#  index_empty_legs_on_road_route_id                               (road_route_id)
#  index_empty_legs_on_tenant_id_and_next_manifest_code            (tenant_id,next_manifest_code) UNIQUE
#  index_empty_legs_on_tenant_id_and_next_transport_document_code  (tenant_id,next_transport_document_code) UNIQUE
#  index_empty_legs_on_tenant_id_and_plate                         (tenant_id,plate)
#  index_empty_legs_on_tenant_id_and_previous_manifest_code        (tenant_id,previous_manifest_code)
#
# Foreign Keys
#
#  fk_rails_...  (destination_id => locations.id)
#  fk_rails_...  (origin_id => locations.id)
#  fk_rails_...  (road_route_id => road_routes.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
