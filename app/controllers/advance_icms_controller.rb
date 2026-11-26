class AdvanceIcmsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_origin_state, as: :origin_state
  has_scope :by_advance_icms_status, as: :status
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :advance_icms)

    transport_documents = apply_scopes(current_tenant.atua_transport_documents.advance_icms)

    @transport_documents = listing_page(apply_sort(transport_documents.with_advance_icms_guide.preload(taker: :customer_group),
                                                   Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, id: :desc))
    @totals = transport_documents.advance_icms_totals
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
    @origin_states = current_tenant.atua_transport_documents.advance_icms.where.not(origin_state: [nil, ''])
      .distinct.order(:origin_state).pluck(:origin_state)

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.advance_icms_xlsx_sheets(@transport_documents) })
  end
end
