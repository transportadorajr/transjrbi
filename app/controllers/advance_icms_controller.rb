class AdvanceIcmsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_origin_state, as: :origin_state
  has_scope :by_advance_icms_status, as: :status
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date
  has_scope :advance_icms_overdue, as: :overdue, type: :boolean

  def index
    authorize!(:read, :advance_icms)

    transport_documents = apply_scopes(current_tenant.atua_transport_documents.advance_icms)

    @transport_documents = listing_page(apply_sort(transport_documents.with_advance_icms_guide.preload(taker: :customer_group),
                                                   Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, id: :desc))
    @totals = transport_documents.advance_icms_totals
    @dashboard = Dashboard::AdvanceIcms.new(transport_documents, billed_documents)
    @group_rows = listing_page(@dashboard.group_rows, param_name: :groups_page)
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
    @origin_states = current_tenant.atua_transport_documents.advance_icms.where.not(origin_state: [nil, ''])
      .distinct.order(:origin_state).pluck(:origin_state)

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.advance_icms_xlsx_sheets(@transport_documents, @group_rows) })
  end

  private

  def billed_documents
    documents = current_tenant.atua_transport_documents.active.not_canceled.freights
    documents = documents.by_period_start(params[:start_date]) if params[:start_date].present?
    documents = documents.by_period_end(params[:end_date]) if params[:end_date].present?
    documents = documents.by_customer_group(params[:customer_group_id]) if params[:customer_group_id].present?

    documents
  end
end
