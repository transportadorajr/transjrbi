module Atua
  class Manifest < ApplicationRecord
    include Importable
    include Sortable
    include Exportable

    CANCELED_STATUS = 'Cancelado'.freeze

    belongs_to :vehicle, class_name: 'Atua::Vehicle', foreign_key: %i[tenant_id plate], primary_key: %i[tenant_id plate],
                         optional: true, inverse_of: :manifests

    has_many :documents, class_name: 'Atua::ManifestDocument', foreign_key: %i[tenant_id manifest_code],
                         primary_key: %i[tenant_id code], inverse_of: :manifest
    has_many :route_documents, -> { active.without_internal_taker.order(:id) }, class_name: 'Atua::ManifestDocument',
                                                                                foreign_key: %i[tenant_id manifest_code],
                                                                                primary_key: %i[tenant_id code], inverse_of: :manifest
    has_many :transport_documents, through: :documents
    has_many :transport_document_manifests, class_name: 'Atua::TransportDocumentManifest',
                                            foreign_key: %i[tenant_id manifest_number branch_name],
                                            primary_key: %i[tenant_id number branch_name], inverse_of: :manifest
    has_one :empty_leg, class_name: 'EmptyLeg', foreign_key: %i[tenant_id next_manifest_code], primary_key: %i[tenant_id code],
                        inverse_of: :next_manifest

    export_field(:driver, &:main_driver_name)
    export_field(:origin) { |manifest| manifest.origins.map { |city, state| [city, state].compact.join('/') } }
    export_field(:destination) { |manifest| manifest.final_destination&.compact&.join('/') }
    export_field(:customer_group, &:customer_groups)
    export_field(:weight_kg, :decimal, &:weight_kg)
    export_field(:loaded_km, :decimal) { |manifest| manifest[:loaded_km] }
    export_field(:gross, :money) { |manifest| manifest[:gross_cents] }
    export_field(:net, :money) { |manifest| manifest[:net_cents] }
    export_field(:gross_per_km, :money) { |manifest| manifest[:gross_per_km_cents] }
    export_field(:net_per_km, :money) { |manifest| manifest[:net_per_km_cents] }
    export_field(:duration_hours, :decimal) { |manifest| manifest[:duration_seconds]&.fdiv(TripDuration::SECONDS_PER_HOUR)&.round(2) }
    export_field(:net_per_hour, :money) { |manifest| manifest[:net_per_hour_cents] }

    monetize :goods_value_cents, allow_nil: true

    sortable :gross_per_km, -> { Arel.sql('gross_per_km_cents') }
    sortable :net_per_km, -> { Arel.sql('net_per_km_cents') }
    sortable :duration, -> { Arel.sql('duration_seconds') }
    sortable :net_per_hour, -> { Arel.sql('net_per_hour_cents') }

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_on: date_range(start_date, end_date)) }
    scope :by_period_start, ->(date) { by_period(date, nil) }
    scope :by_period_end, ->(date) { by_period(nil, date) }
    scope :by_number, ->(number) { where(number: number.to_s.strip) }
    scope :by_departure_period, ->(start_date, end_date) { where(departure_on: date_range(start_date, end_date)) }
    scope :by_plate, ->(plate) { where(plate: normalize_plate(plate)) }
    scope :by_status, ->(status) { where(status:) }
    scope :not_canceled, -> { where.not(status: CANCELED_STATUS).or(where(status: nil)) }
    scope :canceled, -> { where(status: CANCELED_STATUS) }
    scope :with_transport_documents, -> {
      documents = ManifestDocument.arel_table

      where(ManifestDocument.active.joins(:transport_document)
        .where(documents[:tenant_id].eq(arel_table[:tenant_id]))
        .where(documents[:manifest_code].eq(arel_table[:code])).arel.exists)
    }
    scope :trips, -> { active.not_canceled.with_transport_documents.where.not(plate: [nil, '']) }
    scope :by_transport_documents, ->(transport_documents) {
      documents = ManifestDocument.arel_table

      where(ManifestDocument.active.joins(:transport_document).merge(TransportDocument.active.not_canceled.merge(transport_documents))
        .where(documents[:tenant_id].eq(arel_table[:tenant_id]))
        .where(documents[:manifest_code].eq(arel_table[:code])).arel.exists)
    }
    scope :by_driver, ->(code) { by_transport_documents(TransportDocument.by_driver(code)) }
    scope :by_customer_group, ->(customer_group_id) { by_transport_documents(TransportDocument.by_customer_group(customer_group_id)) }
    scope :by_taker, ->(code) { by_transport_documents(TransportDocument.by_taker(code)) }
    scope :by_product_group, ->(product_group_id) { by_transport_documents(TransportDocument.by_product_group(product_group_id)) }
    scope :by_product, ->(product_id) { by_transport_documents(TransportDocument.by_product(product_id)) }
    scope :by_truck_group, ->(truck_group, grouped_plates) {
      by_transport_documents(TransportDocument.by_truck_group(truck_group, grouped_plates))
    }

    scope :with_freight_totals, -> {
      select(
        arel_table[Arel.star],
        Arel::Nodes::Grouping.new(gross_freight).as('gross_cents'),
      )
    }

    class << self
      def with_trip_totals(manifests)
        totals = manifests.with_freight_totals.select(Arel::Nodes::Grouping.new(net_freight).as('net_cents'), Arel::Nodes::Grouping.new(Arel.sql(loaded_km_sql)).as('loaded_km'),
                                                      Arel::Nodes::Grouping.new(Arel.sql(duration_seconds_sql)).as('duration_seconds'))

        from(totals, table_name).select(arel_table[Arel.star], per_km('gross_cents').as('gross_per_km_cents'),
                                        per_km('net_cents').as('net_per_km_cents'), per_hour('net_cents').as('net_per_hour_cents'))
      end

      def duration_seconds_sql
        <<~SQL.squish
          CASE WHEN atua_manifests.closed_at > atua_manifests.trip_started_at
            THEN EXTRACT(EPOCH FROM atua_manifests.closed_at - atua_manifests.trip_started_at)
          END
        SQL
      end

      def in_progress_sql
        'atua_manifests.closed_at IS NULL AND atua_manifests.trip_started_at IS NOT NULL'
      end

      def per_hour(cents_column)
        seconds = arel_table[:duration_seconds]
        cents = Arel::Nodes::Multiplication.new(arel_table[cents_column], Arel::Nodes.build_quoted(TripDuration::SECONDS_PER_HOUR))
        per_hour = Arel::Nodes::NamedFunction.new('ROUND', [Arel::Nodes::Division.new(cents, seconds)])

        Arel::Nodes::Case.new.when(seconds.gteq(TripDuration::MIN_MEASURED.to_i)).then(per_hour)
      end

      def gross_freight(documents = trip_documents)
        Arel::Nodes::Addition.new(
          Arel::Nodes::Grouping.new(documents.select(TransportDocument.sum_or_zero(TransportDocument.arel_table[:freight_cents])).arel),
          missing_documents_freight,
        )
      end

      def net_freight(documents = trip_documents)
        Arel::Nodes::Addition.new(
          Arel::Nodes::Grouping.new(documents.select(TransportDocument.sum_or_zero(TransportDocument.net_freight)).arel),
          missing_documents_freight,
        )
      end

      def missing_documents_freight
        Arel::Nodes::Grouping.new(documents_without_active_transport_document.select(TransportDocument.sum_or_zero(ManifestDocument.arel_table[:freight_cents])).arel)
      end

      def documents_without_active_transport_document
        documents = ManifestDocument.arel_table
        transport_documents = TransportDocument.arel_table
        transport_document = TransportDocument.active.or(TransportDocument.canceled).where(transport_documents[:tenant_id].eq(documents[:tenant_id]))
          .where(transport_documents[:number].eq(documents[:transport_document_number]))
          .where(transport_documents[:series].eq(documents[:transport_document_series]))
          .where(transport_documents[:branch_name].eq(documents[:branch_name]))

        ManifestDocument.active.without_internal_taker
          .where(documents[:tenant_id].eq(arel_table[:tenant_id]))
          .where(documents[:manifest_code].eq(arel_table[:code]))
          .where(transport_document.arel.exists.not)
      end

      def trip_documents
        documents = ManifestDocument.arel_table

        TransportDocument.active.not_canceled.without_ce.joins(:manifest_documents).merge(ManifestDocument.active)
          .where(documents[:tenant_id].eq(arel_table[:tenant_id]))
          .where(documents[:manifest_code].eq(arel_table[:code]))
      end

      def first_trip_documents
        trip_documents.where(<<~SQL.squish, canceled: CANCELED_STATUS)
          NOT EXISTS (
            SELECT 1
            FROM atua_manifest_documents earlier_documents
            INNER JOIN atua_manifests earlier_manifests ON earlier_manifests.tenant_id = earlier_documents.tenant_id
              AND earlier_manifests.code = earlier_documents.manifest_code
            WHERE earlier_documents.tenant_id = atua_transport_documents.tenant_id
              AND earlier_documents.transport_document_number = atua_transport_documents.number
              AND earlier_documents.transport_document_series = atua_transport_documents.series
              AND earlier_documents.branch_name = atua_transport_documents.branch_name
              AND earlier_documents.removed_from_atua_at IS NULL
              AND earlier_manifests.removed_from_atua_at IS NULL
              AND earlier_manifests.status IS DISTINCT FROM :canceled
              AND COALESCE(earlier_manifests.plate, '') <> ''
              AND (COALESCE(earlier_manifests.trip_started_at, earlier_manifests.departure_on, earlier_manifests.issued_on), earlier_manifests.code)
                < (COALESCE(atua_manifests.trip_started_at, atua_manifests.departure_on, atua_manifests.issued_on), atua_manifests.code)
          )
        SQL
      end

      def trip_at
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:trip_started_at], arel_table[:departure_on], arel_table[:issued_on]])
      end

      def trip_on_sql
        started_on = "(atua_manifests.trip_started_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(Time.zone.tzinfo.name)})::date"

        "COALESCE(#{started_on}, atua_manifests.departure_on, atua_manifests.issued_on)"
      end

      def per_km(cents_column)
        loaded_km = Arel::Nodes::NamedFunction.new('NULLIF', [arel_table[:loaded_km], Arel::Nodes.build_quoted(0)])

        Arel::Nodes::NamedFunction.new('ROUND', [Arel::Nodes::Division.new(arel_table[cents_column], loaded_km)])
      end

      def loaded_km_sql
        <<~SQL.squish
          SELECT MAX(GREATEST(COALESCE(distances.calculated_distance_km, 0), COALESCE(distances.document_distance_km, 0)))
          FROM atua_manifest_documents distances
          WHERE distances.tenant_id = atua_manifests.tenant_id AND distances.manifest_code = atua_manifests.code
            AND distances.removed_from_atua_at IS NULL
        SQL
      end

      def empty_km_sql
        <<~SQL.squish
          SELECT empty_legs.distance_km
          FROM empty_legs
          WHERE empty_legs.tenant_id = atua_manifests.tenant_id AND empty_legs.next_manifest_code = atua_manifests.code
            AND empty_legs.status_type = 'calculated'
        SQL
      end
    end

    def canceled?
      status == CANCELED_STATUS
    end

    def trip_on
      trip_started_at&.to_date || departure_on || issued_on
    end

    def trip?
      active? && !canceled? && plate.present?
    end

    def duration
      TripDuration.between(trip_started_at, closed_at)
    end

    def in_progress?
      closed_at.nil? && trip_started_at.present?
    end

    def elapsed
      TripDuration.between(trip_started_at, Time.current) if in_progress?
    end

    def missing_documents_freight
      Money.from_cents(self.class.where(id:).pick(self.class.missing_documents_freight))
    end

    def previous_trip
      trip_at = self.class.trip_at
      started_at = self.class.where(id:).pick(trip_at)
      before = trip_at.lt(started_at).or(trip_at.eq(started_at).and(self.class.arel_table[:code].lt(code)))

      self.class.trips.where(tenant_id:, plate:).where(before).order(trip_at.desc, code: :desc).first
    end

    def origins
      route_cities(:origin_city, :origin_state)
    end

    def destinations
      route_cities(:destination_city, :destination_state)
    end

    def final_destination
      document = route_documents.select(&:on_route?).reverse.find { |route_document| route_document.destination_city.present? }

      [document.destination_city, document.destination_state] if document
    end

    def drivers
      route_documents.select(&:on_route?).filter_map { |document| document.transport_document&.driver_name.presence }.uniq
    end

    def main_driver_name
      document = route_documents.select(&:on_route?).filter_map(&:transport_document)
        .select { |transport_document| transport_document.driver_code && transport_document.document_kind != MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'] }
        .min_by { |transport_document| [-transport_document.freight_cents.to_i, transport_document.id] }

      document&.driver_display_name
    end

    def customer_groups
      route_documents.select(&:on_route?).filter_map { |document| document.transport_document&.customer_group_name.presence }.uniq
    end

    def weight_kg
      weights = route_documents.select(&:on_route?).filter_map(&:weight_kg)
      weights.sum if weights.any?
    end

    def ordered_documents
      documents.active.preload(transport_document: %i[sender recipient]).to_a
        .reject { |document| document.transport_document&.canceled_at }
        .sort_by { |document| [document.transport_document&.issued_at.to_i, document.id] }
    end

    private

    def route_cities(city, state)
      route_documents.select(&:on_route?).map { |document| [document[city], document[state]] }
        .select { |(name, _)| name.present? }.uniq
    end
  end
end

# == Schema Information
#
# Table name: atua_manifests
#
#  id                   :bigint           not null, primary key
#  access_key           :string
#  branch_name          :string
#  closed_at            :datetime
#  code                 :bigint           not null
#  company_city         :string
#  company_state        :string
#  departure_on         :date
#  goods_value_cents    :bigint
#  imported_at          :datetime         not null
#  issued_on            :date
#  model                :integer
#  notes                :text
#  number               :string           not null
#  plate                :string
#  raw_data             :jsonb            not null
#  removed_from_atua_at :datetime
#  series               :integer
#  status               :string
#  trip_started_at      :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  atua_import_id       :bigint
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_atua_manifests_on_atua_import_id                        (atua_import_id)
#  index_atua_manifests_on_tenant_id_and_code                    (tenant_id,code) UNIQUE
#  index_atua_manifests_on_tenant_id_and_departure_on            (tenant_id,departure_on)
#  index_atua_manifests_on_tenant_id_and_issued_on               (tenant_id,issued_on)
#  index_atua_manifests_on_tenant_id_and_number_and_branch_name  (tenant_id,number,branch_name)
#  index_atua_manifests_on_tenant_id_and_plate                   (tenant_id,plate)
#  index_atua_manifests_on_tenant_id_and_status                  (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
