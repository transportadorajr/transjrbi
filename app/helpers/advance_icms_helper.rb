module AdvanceIcmsHelper
  include ChartsHelper

  MONTHLY_SERIES_COLORS = [BRAND_BLUE, CATEGORY_ORANGE].freeze
  ADVANCE_ICMS_STATUS_KINDS = { paid: :success, divergent: :danger, pending: :warning, not_expected: :secondary }.freeze

  def advance_icms_menu(transport_document)
    menus = []

    menus << advance_icms_transport_document_menu(transport_document) if can?(:read, :transport_documents)

    menus
  end

  def advance_icms_transport_document(transport_document)
    return transport_document.number unless can?(:read, :transport_documents)

    link_to transport_document.number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  def advance_icms_status_name(transport_document)
    t(transport_document.advance_icms_status, scope: 'advance_icms.statuses')
  end

  def advance_icms_status_badge(transport_document)
    return status_badge(t('advance_icms.overdue'), kind: :danger) if transport_document.advance_icms_overdue?

    status_badge(advance_icms_status_name(transport_document), kind: ADVANCE_ICMS_STATUS_KINDS.fetch(transport_document.advance_icms_status))
  end

  def advance_icms_overdue_alert(dashboard)
    return if dashboard.overdue_count.zero? || params[:overdue].present?

    render 'advance_icms/overdue_alert', count: dashboard.overdue_count
  end

  def advance_icms_monthly_chart(dashboard)
    column_chart(advance_icms_monthly_series(dashboard.monthly_data), height: CHART_HEIGHT, legend: 'bottom', **chart_money_options,
                                                                      library: chart_bar_library(:x))
  end

  def advance_icms_share(row)
    row.share ? number_to_percentage(row.share, precision: 2) : t('tax.blank')
  end

  def advance_icms_difference(transport_document)
    difference = transport_document.advance_icms_difference
    return tax_money(difference) if difference.zero?

    content_tag(:span, tax_money(difference), class: 'text-danger fw-semibold')
  end

  def advance_icms_counter_cards(totals)
    col_class = 'col-12 col-md-6 col-xl-3'

    safe_join([counter_card(:dark, t('advance_icms.index.total'), totals[:count], col_class:),
               counter_card(:success, t('advance_icms.statuses.paid'), totals[:counts][:paid], col_class:),
               counter_card(:danger, t('advance_icms.statuses.divergent'), totals[:counts][:divergent], col_class:),
               counter_card(:warning, t('advance_icms.statuses.pending'), totals[:counts][:pending], col_class:)])
  end

  def advance_icms_status_options
    options_for_select(Atua::TransportDocument.advance_icms_statuses, params[:status])
  end

  def advance_icms_customer_group_options(customer_groups)
    options_from_collection_for_select(customer_groups, :id, :name, params[:customer_group_id])
  end

  def advance_icms_pdf_report(transport_documents, totals)
    PdfReport.new(
      title: t('advance_icms.index.pdf.header'),
      columns: advance_icms_pdf_columns,
      rows: transport_documents.map do |transport_document|
        [transport_document.number, tax_time(transport_document.issued_at), tax_value(transport_document.taker_name),
         tax_city(transport_document.origin_city, transport_document.origin_state), tax_money(transport_document.icms),
         tax_money(transport_document.advance_icms_guide), tax_money(transport_document.advance_icms_difference),
         advance_icms_status_name(transport_document)]
      end,
      totals: [t('advance_icms.index.pdf.total'), '', '', '', tax_money(totals[:icms]), tax_money(totals[:guide]),
               tax_money(totals[:guide] - totals[:icms]), ''],
    )
  end

  def advance_icms_xlsx_sheets(transport_documents, group_rows)
    columns = [xlsx_field(Atua::TransportDocument.human_attribute_name(:number), &:number),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:issued_at), :datetime, &:issued_at),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:taker), &:taker_name),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:customer_group), &:customer_group_name),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:origin_city), &:origin_city),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:origin_state), &:origin_state),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:cfop), :integer, &:cfop),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:icms), :money, &:icms),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:advance_icms_guide), :money, &:advance_icms_guide),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:advance_icms_difference), :money, &:advance_icms_difference),
               xlsx_field(Atua::TransportDocument.human_attribute_name(:advance_icms_status)) { |document| advance_icms_status_name(document) }]

    [Export::Sheet.new(name: t('advance_icms.index.title'), columns:, rows: transport_documents),
     Export::Sheet.new(name: t('advance_icms.groups.title'), columns: advance_icms_group_xlsx_columns, rows: group_rows)]
  end

  private

  def advance_icms_monthly_series(series)
    series.zip(MONTHLY_SERIES_COLORS).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end

  def advance_icms_group_xlsx_columns
    [xlsx_field(t('advance_icms.groups.customer_group'), &:label),
     xlsx_field(t('advance_icms.groups.count'), :integer, &:count),
     xlsx_field(t('advance_icms.groups.icms'), :money, &:icms),
     xlsx_field(t('advance_icms.groups.guide'), :money, &:guide),
     xlsx_field(t('advance_icms.groups.pending'), :money, &:pending),
     xlsx_field(t('advance_icms.groups.gross'), :money, &:gross),
     xlsx_field(t('advance_icms.groups.share'), :percentage, &:share)]
  end

  def advance_icms_pdf_columns
    [pdf_column(Atua::TransportDocument.human_attribute_name(:number)), pdf_column(Atua::TransportDocument.human_attribute_name(:issued_at)),
     pdf_column(Atua::TransportDocument.human_attribute_name(:taker), '2fr'), pdf_column(Atua::TransportDocument.human_attribute_name(:origin), '1.5fr'),
     pdf_column(Atua::TransportDocument.human_attribute_name(:icms), align: :right),
     pdf_column(Atua::TransportDocument.human_attribute_name(:advance_icms_guide), align: :right),
     pdf_column(Atua::TransportDocument.human_attribute_name(:advance_icms_difference), align: :right),
     pdf_column(Atua::TransportDocument.human_attribute_name(:advance_icms_status))]
  end

  def advance_icms_transport_document_menu(transport_document)
    Menu.new(name: :show, record: transport_document, url: transport_document_path(transport_document), icon: :eye)
  end
end
