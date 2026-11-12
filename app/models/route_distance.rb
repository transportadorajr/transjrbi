class RouteDistance < ApplicationRecord
  include Sortable
  include Exportable

  export_field(:customer_name) { |route_distance| route_distance.customer&.name }
  export_field(:documents_count, :integer) { |route_distance| route_distance[:documents_count] }

  sortable :customer_name, -> { sort_text(customer_name) }
  sortable :origin_city
  sortable :destination_city
  sortable :distance_km, -> { arel_table[:distance_km] }

  belongs_to :tenant
  belongs_to :customer, class_name: 'Atua::Customer', foreign_key: %i[tenant_id customer_code], primary_key: %i[tenant_id code],
                        optional: true, inverse_of: false
  has_many :transport_documents, class_name: 'Atua::TransportDocument', dependent: nil, inverse_of: :route_distance

  validates :customer_code, :origin_city, :origin_state, :destination_city, :destination_state, :distance_km, presence: true
  validates :distance_km, numericality: { greater_than: 0 }
  validates :destination_city, uniqueness: { scope: %i[tenant_id customer_code origin_state origin_city destination_state] }

  scope :by_customer, ->(code) { where(customer_code: code) }
  scope :by_origin, ->(city) { where(arel_table[:origin_city].matches("%#{sanitize_sql_like(normalize_city(city))}%")) }
  scope :by_destination, ->(city) { where(arel_table[:destination_city].matches("%#{sanitize_sql_like(normalize_city(city))}%")) }
  scope :with_documents_count, -> {
    documents = Atua::TransportDocument.arel_table
    count = Atua::TransportDocument.where(documents[:route_distance_id].eq(arel_table[:id])).select(documents[Arel.star].count)

    select(arel_table[Arel.star], count.arel.as('documents_count'))
  }

  class << self
    def normalize_city(value)
      I18n.transliterate(value.to_s).upcase.squish
    end

    def route_key(customer_code, origin_city, origin_state, destination_city, destination_state)
      [customer_code, *[origin_city, origin_state, destination_city, destination_state].map { |part| normalize_city(part) }]
    end

    def customer_name
      customers = Atua::Customer.arel_table

      Arel::Nodes::Grouping.new(
        Atua::Customer.where(customers[:tenant_id].eq(arel_table[:tenant_id]).and(customers[:code].eq(arel_table[:customer_code])))
          .select(customers[:name]).arel,
      )
    end
  end

  def route_key
    self.class.route_key(customer_code, origin_city, origin_state, destination_city, destination_state)
  end
end

# == Schema Information
#
# Table name: route_distances
#
#  id                :bigint           not null, primary key
#  customer_code     :bigint           not null
#  destination_city  :string           not null
#  destination_state :string           not null
#  distance_km       :decimal(14, 2)   not null
#  origin_city       :string           not null
#  origin_state      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_route_distances_on_customer_and_route  (tenant_id,customer_code,origin_state,origin_city,destination_state,destination_city) UNIQUE
#  index_route_distances_on_tenant_id           (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
