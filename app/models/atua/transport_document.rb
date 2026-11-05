module Atua
  class TransportDocument < ApplicationRecord
    include Importable
    include Sortable

    INACTIVITY_PERIOD = 12.months
    VALUE_COMPLEMENT = 'Complemento de Valores'.freeze
    TOLL_TOLERANCE_CENTS = 1
    FREIGHT_PARTS = %i[weight_freight_cents ad_valorem_cents other_charges_cents toll_cents icms_cents].freeze
    INTERNAL_TAKER_DOCUMENTS = %w[10212838000100 10212838000283 10212838000364 51628145000172 27676883000100 39622838000152].freeze
    CARGO_DESTINATIONS = %i[national export import].freeze

    with_options class_name: 'Atua::Customer', primary_key: %i[tenant_id code], optional: true, inverse_of: false do
      belongs_to :sender, foreign_key: %i[tenant_id sender_code]
      belongs_to :recipient, foreign_key: %i[tenant_id recipient_code]
      belongs_to :payer, foreign_key: %i[tenant_id payer_code]
      belongs_to :taker, foreign_key: %i[tenant_id taker_code]
      belongs_to :consignee, foreign_key: %i[tenant_id consignee_code]
    end
    with_options class_name: 'Atua::Vehicle', optional: true do
      belongs_to :vehicle, foreign_key: %i[tenant_id vehicle_code], primary_key: %i[tenant_id code], inverse_of: :transport_documents
      belongs_to :trailer, foreign_key: %i[tenant_id trailer_plate], primary_key: %i[tenant_id plate],
                           inverse_of: :trailer_transport_documents
    end

    belongs_to :origin_macro_region, class_name: 'MacroRegion', optional: true, inverse_of: :transport_documents
    belongs_to :product_group, optional: true, inverse_of: :transport_documents
    belongs_to :route_distance, optional: true, inverse_of: :transport_documents
    belongs_to :complemented_transport_document, class_name: 'Atua::TransportDocument', optional: true, inverse_of: :value_complements

    has_many :value_complements, class_name: 'Atua::TransportDocument', foreign_key: :complemented_transport_document_id,
                                 inverse_of: :complemented_transport_document

    has_many :transport_document_manifests, class_name: 'Atua::TransportDocumentManifest',
                                            foreign_key: %i[tenant_id transport_document_code], primary_key: %i[tenant_id code],
                                            inverse_of: :transport_document
    has_many :manifests, through: :transport_document_manifests
    has_many :manifest_documents, class_name: 'Atua::ManifestDocument',
                                  foreign_key: %i[tenant_id transport_document_number transport_document_series branch_name],
                                  primary_key: %i[tenant_id number series branch_name], inverse_of: :transport_document
    has_many :expenses, class_name: 'Atua::Expense', as: :cost_object, inverse_of: :cost_object
    has_many :empty_leg_transport_documents, foreign_key: %i[tenant_id transport_document_code], primary_key: %i[tenant_id code],
                                             inverse_of: :transport_document
    has_many :empty_legs, through: :empty_leg_transport_documents
    has_many :freight_expenses, dependent: :delete_all, inverse_of: :transport_document
    has_many :toll_vouchers, class_name: 'Atua::TollVoucher', foreign_key: %i[tenant_id transport_document_number branch_code],
                             primary_key: %i[tenant_id number branch_code], inverse_of: :transport_document

    monetize :goods_value_cents, :freight_cents, :weight_freight_cents, :value_freight_cents, :ad_valorem_cents,
             :other_charges_cents, :toll_cents, :icms_base_cents, :icms_cents, :icms_st_cents, :federal_tax_cents,
             :ibs_cents, :cbs_cents, :result_cents, :driver_freight_cents, :advance_cents, :commission_cents,
             :insurance_cents, :cost_cents, allow_nil: true

    enum :cargo_destination_type, CARGO_DESTINATIONS.index_with(&:to_s), prefix: :cargo, validate: { allow_nil: true }

    sortable :customer_name, -> { sort_text(customer_group_name) }
    sortable :driver_name
    sortable :gross, -> { arel_table[:freight_cents] }
    sortable :net, -> { Arel.sql('net_cents') }

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_at: time_range(start_date, end_date)) }
    scope :by_posted_period, ->(start_date, end_date) { where(posted_on: date_range(start_date, end_date)) }
    scope :by_period_start, ->(date) { by_posted_period(date, nil) }
    scope :by_period_end, ->(date) { by_posted_period(nil, date) }
    scope :by_number, ->(number) { where(number: number.to_s.strip) }
    scope :by_plate, ->(plate) {
      plate = normalize_plate(plate)
      where(plate:).or(where(trailer_plate: plate))
    }
    scope :by_vehicle, ->(vehicle) {
      where(tenant_id: vehicle.tenant_id).and(where(vehicle_code: vehicle.code).or(where(trailer_plate: vehicle.plate)))
    }
    scope :by_customer, ->(code) {
      where(sender_code: code).or(where(recipient_code: code)).or(where(payer_code: code))
        .or(where(taker_code: code)).or(where(consignee_code: code))
    }
    scope :by_payer, ->(code) { where(payer_code: code) }
    scope :by_taker, ->(code) { where(taker_code: code) }
    scope :with_internal_taker, -> {
      customers = Customer.arel_table

      where(taker_code: Customer.where(document_digits: INTERNAL_TAKER_DOCUMENTS).where(customers[:tenant_id].eq(arel_table[:tenant_id])).select(:code))
    }
    scope :by_driver, ->(code) { where(driver_code: code) }
    scope :drivers, -> {
      active.where.not(driver_code: nil).group(:driver_code).select(:driver_code, arel_table[:driver_name].maximum.as('driver_name')).order(arel_table[:driver_name].maximum)
    }
    scope :by_customer_group, ->(customer_group_id) {
      where(taker_code: Customer.where(customer_group_id:).select(:code))
    }
    scope :by_product_group, ->(product_group_id) { where(product_group_id: ProductGroup.where(parent_id: product_group_id).select(:id)) }
    scope :by_branch, ->(code) { where(branch_code: code) }
    scope :recently_issued, -> { where(issued_at: INACTIVITY_PERIOD.ago..) }
    scope :by_origin_macro_region, ->(macro_region_id) {
      where(origin_macro_region_id: macro_region_id.to_s == MacroRegion::OTHERS ? nil : macro_region_id)
    }
    scope :not_canceled, -> { where(canceled_at: nil) }
    scope :without_issuers, ->(codes) { where.not(issuer_code: codes).or(where(issuer_code: nil)) }
    scope :canceled, -> { where.not(canceled_at: nil) }
    scope :without_ce, -> { where(arel_table[:document_kind].is_distinct_from(MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'])) }
    scope :commissionable, -> {
      active.not_canceled.where(document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CTRC'])
        .where(arel_table[:issue_kind].is_distinct_from(VALUE_COMPLEMENT))
    }
    scope :with_valid_manifest, -> {
      where(id: joins(:manifests).merge(TransportDocumentManifest.active).merge(Manifest.active.not_canceled).select(:id))
    }
    scope :vehicle_sales, -> { where(vehicle_sale: true) }
    scope :freights, -> { where(vehicle_sale: false) }
    scope :by_axles, ->(axles) { where(axles:) }
    scope :without_axles, ->(axles) { where(arel_table[:axles].not_in(axles).or(arel_table[:axles].eq(nil))) }
    scope :without_plates, ->(plates) { where(arel_table[:plate].not_in(plates).or(arel_table[:plate].eq(nil))) }
    scope :by_truck_group, ->(truck_group, grouped_plates) {
      outside_plates = arel_table[:plate].not_in(grouped_plates).or(arel_table[:plate].eq(nil))

      where(arel_table[:plate].in(truck_group.plates).or(arel_table[:axles].in(truck_group.axles).and(outside_plates)))
    }

    scope :with_freight_totals, -> { select(arel_table[Arel.star], net_freight.as('net_cents')) }
    scope :billing_only, -> {
      where(document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'])
        .where(arel_table[:plate].eq(MapTransportDocumentsCommand::INTERNATIONAL_PLATE).or(billed_to_border))
    }

    class << self
      def vehicle_sale?(record)
        record[:document_kind] == MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'] &&
          INTERNAL_TAKER_DOCUMENTS.include?(record[:sender_document_digits]) &&
          record[:freight_cents].to_i.positive? && record[:freight_cents] == record[:goods_value_cents]
      end

      def vehicle_sale_condition
        arel_table[:document_kind].eq(MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'])
          .and(arel_table[:sender_document_digits].in(INTERNAL_TAKER_DOCUMENTS))
          .and(arel_table[:freight_cents].gt(0))
          .and(arel_table[:freight_cents].eq(arel_table[:goods_value_cents]))
      end

      def international_vehicle(tenant)
        attributes = { plate: MapTransportDocumentsCommand::INTERNATIONAL_PLATE, trailer_plate: nil }
        vehicle_code = tenant.atua_vehicles.by_plate(MapTransportDocumentsCommand::INTERNATIONAL_PLATE).pick(:code)

        vehicle_code ? attributes.merge(vehicle_code:) : attributes
      end

      def billed_to_border
        arel_table[:destination_city].eq(MapTransportDocumentsCommand::BILLING_DESTINATION[:destination_city])
          .and(arel_table[:destination_state].eq(MapTransportDocumentsCommand::BILLING_DESTINATION[:destination_state]))
          .and(arel_table[:taker_name].matches("%#{MapTransportDocumentsCommand::BILLING_ORIGIN_TAKER}%"))
      end

      def net_freight
        Arel::Nodes::Case.new.when(arel_table[:canceled_at].eq(nil)).then(net_freight_of_document)
      end

      def net_freight_of_document
        zero_if_null(:freight_cents) - Arel::Nodes::Grouping.new(freight_expenses_total.arel) - expenses_with_complements - discounted_toll
      end

      def expenses_with_complements
        Arel::Nodes::Grouping.new(
          Arel::Nodes::Subtraction.new(
            Arel::Nodes::Addition.new(Arel::Nodes::Grouping.new(expenses_total.arel), complement_transfer),
            Arel::Nodes::Grouping.new(complement_credits_total),
          ),
        )
      end

      def complement_credits_total
        complements = arel_table.alias('value_complements')

        Arel::SelectManager.new(complements).project(sum_or_zero(complements[:freight_cents]))
          .where(complements[:complemented_transport_document_id].eq(arel_table[:id]))
          .where(complements[:removed_from_atua_at].eq(nil))
          .where(complements[:canceled_at].eq(nil))
      end

      def complement_transfer
        Arel::Nodes::Case.new.when(arel_table[:complemented_transport_document_id].not_eq(nil)).then(zero_if_null(:freight_cents)).else(0)
      end

      def freight_expenses_total
        FreightExpense.where(FreightExpense.arel_table[:transport_document_id].eq(arel_table[:id]))
          .select(sum_or_zero(FreightExpense.arel_table[:amount_cents]))
      end

      def expenses_total
        Atua::Expense.active.freight.where(Atua::Expense.arel_table[:cost_object_id].eq(arel_table[:id]))
          .select(sum_or_zero(Atua::Expense.arel_table[:total_cents]))
      end

      def customer_group_name
        customers = Customer.arel_table
        group_name = Customer.joins(:customer_group).where(customers[:tenant_id].eq(arel_table[:tenant_id]))
          .where(customers[:code].eq(arel_table[:taker_code])).select(CustomerGroup.arel_table[:name]).limit(1)

        Arel::Nodes::NamedFunction.new('COALESCE', [Arel::Nodes::Grouping.new(group_name.arel), arel_table[:taker_name]])
      end

      def sum_or_zero(column)
        Arel::Nodes::NamedFunction.new('COALESCE', [column.sum, Arel::Nodes.build_quoted(0)])
      end

      def export_origin
        Arel::Nodes::Grouping.new(
          arel_table[:origin_city].eq(MapTransportDocumentsCommand::REAL_ORIGIN[:origin_city])
            .and(arel_table[:origin_state].eq(MapTransportDocumentsCommand::REAL_ORIGIN[:origin_state]))
            .and(arel_table[:document_kind].eq(MapTransportDocumentsCommand::DOCUMENT_KINDS['CE']))
            .and(arel_table[:plate].eq(MapTransportDocumentsCommand::INTERNATIONAL_PLATE)
              .or(arel_table[:taker_name].matches("%#{MapTransportDocumentsCommand::BILLING_ORIGIN_TAKER}%"))),
        )
      end

      def discounted_toll
        vouchers = Arel::Nodes::NamedFunction.new('NULLIF', [Arel::Nodes::Grouping.new(toll_vouchers_total.arel), Arel::Nodes.build_quoted(0)])

        Arel::Nodes::Case.new
          .when(toll_outside_freight).then(0)
          .else(Arel::Nodes::NamedFunction.new('COALESCE', [vouchers, zero_if_null(:toll_cents)]))
      end

      def undiscounted_toll
        Arel::Nodes::Case.new.when(toll_outside_freight).then(arel_table[:toll_cents]).else(0)
      end

      def toll_vouchers_total
        vouchers = TollVoucher.arel_table

        TollVoucher.active.not_canceled
          .where(vouchers[:tenant_id].eq(arel_table[:tenant_id]))
          .where(vouchers[:transport_document_number].eq(arel_table[:number]))
          .where(vouchers[:branch_code].eq(arel_table[:branch_code]))
          .select(sum_or_zero(vouchers[:toll_cents]))
      end

      def taker_names_by_code
        where.not(taker_name: [nil, '']).distinct.pluck(:taker_code, :taker_name)
          .group_by(&:first).transform_values { |rows| rows.map(&:last) }
      end

      private

      def toll_outside_freight
        columns = FREIGHT_PARTS.map { |column| zero_if_null(column) }
        parts = columns.drop(1).sum(columns.first)
        difference = Arel::Nodes::NamedFunction.new('ABS', [Arel::Nodes::Grouping.new(zero_if_null(:freight_cents) - parts)])

        zero_if_null(:toll_cents).gt(0).and(difference.gt(TOLL_TOLERANCE_CENTS))
      end

      def zero_if_null(column)
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[column], Arel::Nodes.build_quoted(0)])
      end
    end

    def customer_group_name
      taker&.customer_group&.name.presence || taker_name
    end

    def canceled?
      canceled_at.present?
    end

    def complement_credits
      value_complements.active.not_canceled
    end

    def complement_credit
      Money.from_cents(-freight_cents.to_i)
    end

    def complement_transfer
      Money.from_cents(complemented_transport_document_id && !canceled? ? freight_cents.to_i : 0)
    end

    def toll_placement
      return :none unless toll_cents.to_i.positive?

      toll_in_freight? ? :in_freight : :outside_freight
    end

    def toll_voucher_paid
      Money.from_cents(toll_vouchers.active.not_canceled.sum(:toll_cents))
    end

    def atua_toll_kind
      raw_data['id_pedagio_ctrc'].presence
    end

    def linked_manifests
      Manifest.where(tenant_id:).and(
        Manifest.where(id: manifests.select(:id)).or(Manifest.where(code: manifest_documents.active.select(:manifest_code))),
      )
    end

    def toll_voucher_issuer
      raw_data['nm_emissao_vale_pedagio'].presence
    end

    private

    def toll_in_freight?
      (freight_cents.to_i - FREIGHT_PARTS.sum { |column| self[column].to_i }).abs <= TOLL_TOLERANCE_CENTS
    end
  end
end

# == Schema Information
#
# Table name: atua_transport_documents
#
#  id                                 :bigint           not null, primary key
#  access_key                         :string
#  ad_valorem_cents                   :bigint
#  advance_cents                      :bigint
#  agency_code                        :bigint
#  agency_name                        :string
#  arrival_on                         :date
#  axles                              :integer
#  billing_number                     :string
#  branch_code                        :bigint
#  branch_name                        :string
#  canceled_at                        :datetime
#  cancellation_reason                :string
#  cargo_destination_type             :enum
#  cbs_cents                          :bigint
#  cfop                               :integer
#  charged_at                         :datetime
#  ciot                               :string
#  code                               :bigint           not null
#  commission_cents                   :bigint
#  complemented_number                :string
#  consignee_code                     :bigint
#  consignee_document                 :string
#  consignee_document_digits          :string
#  consignee_name                     :string
#  cost_cents                         :bigint
#  cte_status                         :string
#  destination_city                   :string
#  destination_city_code              :bigint
#  destination_state                  :string
#  distance_adjusted_at               :datetime
#  distance_km                        :decimal(14, 2)
#  document_kind                      :string
#  driver_code                        :bigint
#  driver_document                    :string
#  driver_document_digits             :string
#  driver_freight_cents               :bigint
#  driver_name                        :string
#  due_dates                          :date             default([]), not null, is an Array
#  federal_tax_cents                  :bigint
#  freight_cents                      :bigint
#  goods_invoice_keys                 :string           default([]), not null, is an Array
#  goods_invoice_numbers              :string           default([]), not null, is an Array
#  goods_value_cents                  :bigint
#  headquarters_code                  :bigint
#  headquarters_name                  :string
#  ibs_cents                          :bigint
#  icms_base_cents                    :bigint
#  icms_cents                         :bigint
#  icms_st_cents                      :bigint
#  imported_at                        :datetime         not null
#  insurance_cents                    :bigint
#  issue_kind                         :string
#  issued_at                          :datetime
#  issuer_code                        :integer
#  issuer_name                        :string
#  manifest_numbers                   :string           default([]), not null, is an Array
#  ncm                                :string
#  nfse_pending_at                    :datetime
#  number                             :string           not null
#  operational_unit                   :string
#  origin_city                        :string
#  origin_city_code                   :bigint
#  origin_state                       :string
#  original_distance_km               :decimal(14, 2)
#  other_charges_cents                :bigint
#  payer_code                         :bigint
#  payer_document                     :string
#  payer_document_digits              :string
#  payer_name                         :string
#  plate                              :string
#  posted_on                          :date
#  product_name                       :string
#  product_quantity                   :decimal(14, 3)
#  raw_data                           :jsonb            not null
#  recipient_code                     :bigint
#  recipient_document                 :string
#  recipient_document_digits          :string
#  recipient_name                     :string
#  removed_from_atua_at               :datetime
#  result_cents                       :bigint
#  result_margin_percentage           :decimal(12, 4)
#  route                              :string
#  sender_code                        :bigint
#  sender_document                    :string
#  sender_document_digits             :string
#  sender_name                        :string
#  series                             :integer
#  service_kind                       :string
#  shipment_number                    :string
#  taker_code                         :bigint
#  taker_name                         :string
#  toll_cents                         :bigint
#  trailer_plate                      :string
#  value_freight_cents                :bigint
#  vehicle_code                       :bigint
#  vehicle_ownership                  :string
#  vehicle_sale                       :boolean          default(FALSE), not null
#  weight_freight_cents               :bigint
#  weight_kg                          :decimal(14, 2)
#  weight_tons                        :decimal(14, 3)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  atua_import_id                     :bigint
#  complemented_transport_document_id :bigint
#  origin_macro_region_id             :bigint
#  product_group_id                   :bigint
#  route_distance_id                  :bigint
#  tenant_id                          :bigint           not null
#
# Indexes
#
#  idx_on_complemented_transport_document_id_6691e9e8ef            (complemented_transport_document_id)
#  idx_on_tenant_id_number_series_branch_name_82ba4806a5           (tenant_id,number,series,branch_name)
#  index_atua_transport_documents_on_atua_import_id                (atua_import_id)
#  index_atua_transport_documents_on_manifest_numbers              (manifest_numbers) USING gin
#  index_atua_transport_documents_on_origin_macro_region_id        (origin_macro_region_id)
#  index_atua_transport_documents_on_product_group_id              (product_group_id)
#  index_atua_transport_documents_on_route_distance_id             (route_distance_id)
#  index_atua_transport_documents_on_tenant_id_and_code            (tenant_id,code) UNIQUE
#  index_atua_transport_documents_on_tenant_id_and_consignee_code  (tenant_id,consignee_code)
#  index_atua_transport_documents_on_tenant_id_and_cte_status      (tenant_id,cte_status)
#  index_atua_transport_documents_on_tenant_id_and_issued_at       (tenant_id,issued_at)
#  index_atua_transport_documents_on_tenant_id_and_issuer_code     (tenant_id,issuer_code)
#  index_atua_transport_documents_on_tenant_id_and_payer_code      (tenant_id,payer_code)
#  index_atua_transport_documents_on_tenant_id_and_plate           (tenant_id,plate)
#  index_atua_transport_documents_on_tenant_id_and_posted_on       (tenant_id,posted_on)
#  index_atua_transport_documents_on_tenant_id_and_recipient_code  (tenant_id,recipient_code)
#  index_atua_transport_documents_on_tenant_id_and_sender_code     (tenant_id,sender_code)
#  index_atua_transport_documents_on_tenant_id_and_taker_code      (tenant_id,taker_code)
#  index_atua_transport_documents_on_tenant_id_and_trailer_plate   (tenant_id,trailer_plate)
#  index_atua_transport_documents_on_tenant_id_and_vehicle_code    (tenant_id,vehicle_code)
#  index_atua_transport_documents_on_tenant_id_and_vehicle_sale    (tenant_id,vehicle_sale)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (complemented_transport_document_id => atua_transport_documents.id) ON DELETE => nullify
#  fk_rails_...  (origin_macro_region_id => macro_regions.id) ON DELETE => nullify
#  fk_rails_...  (product_group_id => product_groups.id)
#  fk_rails_...  (route_distance_id => route_distances.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
