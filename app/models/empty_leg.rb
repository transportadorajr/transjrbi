class EmptyLeg < ApplicationRecord
  STATUSES = %i[calculated unlocated unrouted].freeze

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
  with_options class_name: 'Atua::TransportDocument', primary_key: %i[tenant_id code], optional: true do
    belongs_to :previous_transport_document, foreign_key: %i[tenant_id previous_transport_document_code], inverse_of: false
    belongs_to :next_transport_document, foreign_key: %i[tenant_id next_transport_document_code], inverse_of: :ce_empty_leg
  end

  enum :status_type, STATUSES.index_with(&:to_s), validate: true
  enum :precision_type, Location::PRECISIONS.index_with(&:to_s), prefix: :precision, validate: { allow_nil: true }

  validates :plate, :calculated_at, presence: true
  validates :previous_manifest_code, presence: true, unless: :previous_transport_document_code?
  validates :next_manifest_code, presence: true, unless: :next_transport_document_code?
  validates :next_manifest_code, uniqueness: { scope: :tenant_id }, allow_nil: true
  validates :next_transport_document_code, uniqueness: { scope: :tenant_id }, allow_nil: true
  validates :distance_km, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :calculated?

  class << self
    def trip_at
      Arel::Nodes::NamedFunction.new('COALESCE', [Atua::Manifest.trip_at, Atua::TransportDocument.arel_table[:issued_at]])
    end
  end

  def trip_on
    next_manifest&.trip_on || next_transport_document&.issued_at&.to_date
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
