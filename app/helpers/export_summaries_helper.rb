module ExportSummariesHelper
  include ChartsHelper

  CATEGORY_ORANGE = '#f97316'.freeze
  COUNTRY_COLORS = [BRAND_BLUE, CATEGORY_ORANGE, '#93c5fd', '#fdba74', '#1e3a8a', '#c2410c'].freeze
  UNKNOWN_COUNTRY_COLOR = '#adb5bd'.freeze
  DOCUMENTS_MODAL_ID = 'export_summary_documents_modal'.freeze
  TONS_PRECISION = 1

  def export_summary_content_partial(dashboard)
    dashboard.empty? ? 'shared/no_content' : 'export_summaries/report'
  end

  def export_summary_period_presets
    ExportSummaryFilterForm::PERIOD_PRESETS
  end

  def export_summary_period_preset_label(preset)
    t(preset, scope: 'export_summaries.period_presets')
  end

  def export_summary_period_preset_path(preset)
    period = ExportSummaryFilterForm.preset_period(preset)

    export_summary_path(**request.query_parameters.symbolize_keys.except(:page, :detail, :documents_page), start_date: period.first,
                                                                                                           end_date: period.last)
  end

  def export_summary_period_preset_link_class(preset, filter_form)
    variation = filter_form.preset_period(preset) == filter_form.period ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def export_summary_period_label(filter_form)
    t('export_summaries.show.period', from: l(filter_form.start_date), to: l(filter_form.end_date))
  end

  def export_summary_last_sync_label(last_synced_at)
    return t('export_summaries.show.never_synced') unless last_synced_at

    t('export_summaries.show.last_sync', time: l(last_synced_at, format: :date_time))
  end

  def export_summary_tons(tons)
    t('export_summaries.tons', value: number_with_precision(tons, precision: TONS_PRECISION, delimiter: t('number.format.delimiter'),
                                                                  separator: t('number.format.separator')))
  end

  def export_summary_share(share)
    number_to_percentage(share, precision: 1)
  end

  def export_summary_comparison_title(comparison, period)
    t("export_summaries.comparison.#{period}", from: l(comparison.current_period.first, format: :chart_week),
                                               to: l(comparison.current_period.last, format: :chart_week))
  end

  def export_summary_comparison_loadings(comparison)
    t('export_summaries.comparison.loadings', count: comparison.current_loadings)
  end

  def export_summary_comparison_variation(comparison)
    previous = t('export_summaries.comparison.previous', from: l(comparison.previous_period.first, format: :chart_week),
                                                         to: l(comparison.previous_period.last, format: :chart_week),
                                                         tons: export_summary_tons(comparison.previous_tons))
    return content_tag(:p, t('export_summaries.comparison.no_previous', previous:), class: 'small mb-0 text-body-secondary') if comparison.variation.nil?

    variation = number_to_percentage(comparison.variation, precision: 1, format: comparison.variation.positive? ? '+%n%' : '%n%')
    content_tag(:p, t('export_summaries.comparison.variation', variation:, previous:), class: "small mb-0 #{export_summary_variation_class(comparison)}")
  end

  def export_summary_variation_class(comparison)
    return 'text-body-secondary' if comparison.variation.zero?

    comparison.variation.positive? ? 'text-success' : 'text-danger'
  end

  def export_summary_monthly_subtitle(dashboard)
    months = dashboard.months

    t('export_summaries.show.monthly_subtitle', from: l(months.first, format: :chart_month).capitalize,
                                                to: l(months.last, format: :chart_month).capitalize)
  end

  def export_summary_weekly_subtitle(dashboard)
    weeks = dashboard.weeks

    t('export_summaries.show.weekly_subtitle', from: l(weeks.first), to: l(weeks.last.end_of_week(Dashboard::Export::WEEK_START)))
  end

  def export_summary_evolution_cards(dashboard)
    safe_join(EVOLUTIONS.map do |evolution|
      chart_evolution_item(evolution) do
        render 'freight_billings/chart_card', title: t("export_summaries.show.#{evolution}_title"),
                                              subtitle: public_send(:"export_summary_#{evolution}_subtitle", dashboard),
                                              chart: export_summary_history_chart(dashboard.public_send(:"#{evolution}_data"))
      end
    end)
  end

  def export_summary_history_chart(data)
    column_chart(export_summary_country_series(data), stacked: true, height: CHART_HEIGHT, legend: 'bottom',
                                                      suffix: " #{t('export_summaries.tons_unit')}", thousands: t('number.format.delimiter'),
                                                      decimal: t('number.format.separator'), round: TONS_PRECISION,
                                                      library: chart_bar_library(:x))
  end

  def export_summary_country_series(data)
    colors = COUNTRY_COLORS.cycle
    unknown = t('dashboards.export.unknown_country')

    data.map do |serie|
      color = serie[:name] == unknown ? UNKNOWN_COUNTRY_COLOR : colors.next
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 36 })
    end
  end

  def export_summary_shortcuts(summaries)
    return if summaries.empty?

    render 'export_summaries/shortcuts', summaries:
  end

  def export_summary_shortcut_line(period, comparison)
    parts = [content_tag(:span, t(period, scope: 'export_summaries.shortcuts'), class: 'text-body-secondary'),
             content_tag(:strong, export_summary_tons(comparison.current_tons)),
             content_tag(:span, export_summary_comparison_loadings(comparison), class: 'text-body-secondary'),
             export_summary_shortcut_variation(comparison)]

    content_tag(:p, safe_join(parts, ' · '), class: 'small mb-0')
  end

  def export_summary_shortcut_variation(comparison)
    return content_tag(:span, t('export_summaries.shortcuts.no_previous'), class: 'text-body-secondary') if comparison.variation.nil?

    variation = number_to_percentage(comparison.variation, precision: 1, format: comparison.variation.positive? ? '+%n%' : '%n%')
    content_tag(:span, variation, class: export_summary_variation_class(comparison))
  end

  def export_summary_shortcut_path(shortcut)
    query = request.query_parameters.symbolize_keys.except(:page, :detail, :documents_page, :customer_group_id, :plant, :country)

    export_summary_path(**query, shortcut_id: shortcut.id)
  end

  def export_summary_shortcut_filter(shortcut)
    return unless shortcut

    render 'export_summaries/shortcut_filter', shortcut:
  end

  def export_summary_without_shortcut_path
    export_summary_path(**request.query_parameters.symbolize_keys.except(:page, :detail, :documents_page, :shortcut_id))
  end

  def export_summary_shortcut_hidden_field(form, filter_form)
    form.hidden_field(:shortcut_id, value: filter_form.shortcut_id) if filter_form.shortcut_id.present?
  end

  def export_summary_customer_group_options(dashboard)
    dashboard.customer_group_options.map { |name, id| [name, id.to_s] }
  end

  def export_summary_row_customer_group(row)
    return if export_summary_total?(row)

    country = content_tag(:span, " · #{row.country}", class: 'd-md-none')

    content_tag(:span, safe_join([row.customer_group, country]), class: 'text-muted text-small d-block text-break')
  end

  def export_summary_row_country(row)
    row.country unless export_summary_total?(row)
  end

  def export_summary_total?(row)
    row.key == Dashboard::Export::TOTAL_KEY
  end

  def export_summary_row_menu(row)
    menus = []

    menus << export_summary_documents_menu(row) if can?(:read, :export_summary) && row.documents_count.positive?

    menus
  end

  def export_summary_opened_detail(row, documents)
    return unless row

    render 'export_summaries/documents_modal', row:, documents:, replace_url: export_summary_path(request.query_parameters.except('detail', 'documents_page'))
  end

  def export_summary_documents_pagination_params(row)
    request.query_parameters.symbolize_keys.except(:page, :key).merge(controller: 'export_summaries', action: 'show', detail: row.key)
  end

  def export_summary_document_number(fact)
    return fact.number unless can?(:read, :transport_documents)

    link_to fact.number, transport_document_path(fact.document_id), class: 'fw-semibold', data: { turbo_frame: '_top' }
  end

  def export_summary_document_origin(fact)
    tax_city(fact.origin_city, fact.origin_state)
  end

  def export_summary_pdf_report(dashboard, rows, filter_form)
    PdfReport.new(
      title: t('export_summaries.show.pdf.header'),
      subtitle: export_summary_period_label(filter_form),
      highlights: export_summary_pdf_highlights(dashboard),
      columns: export_summary_pdf_columns,
      rows: rows.map { |row| export_summary_pdf_row(row) },
      totals: (export_summary_pdf_row(dashboard.total) unless dashboard.empty?),
    )
  end

  def export_summary_xlsx_sheets(dashboard)
    rows = dashboard.empty? ? dashboard.rows : [*dashboard.rows, dashboard.total]
    documents = dashboard.documents_for(Dashboard::Export::TOTAL_KEY)

    [Export::Sheet.new(name: t('export_summaries.show.title'), columns: export_summary_xlsx_row_columns, rows:),
     Export::Sheet.new(name: t('export_summaries.xlsx.documents'), columns: export_summary_xlsx_document_columns(dashboard), rows: documents)]
  end

  private

  def export_summary_documents_menu(row)
    Menu.new(name: :documents, record: row, url: documents_export_summary_path(**request.query_parameters.symbolize_keys.except(:page), key: row.key),
             icon: :'list-ul', data: { turbo_stream: true })
  end

  def export_summary_pdf_highlights(dashboard)
    [pdf_highlight(t('export_summaries.show.tons'), export_summary_tons(dashboard.total.tons)),
     pdf_highlight(t('export_summaries.show.loadings'), dashboard.total.loadings_count),
     pdf_highlight(t('export_summaries.show.documents'), dashboard.total.documents_count)]
  end

  def export_summary_pdf_columns
    [pdf_column(t('export_summaries.columns.customer_group'), '2fr'), pdf_column(t('export_summaries.columns.plant'), '2fr'),
     pdf_column(t('export_summaries.columns.country'), '1.5fr'),
     *%i[tons loadings documents share].map { |column| pdf_column(t(column, scope: 'export_summaries.columns'), align: :right) }]
  end

  def export_summary_pdf_row(row)
    [row.customer_group, row.plant, row.country, export_summary_tons(row.tons), row.loadings_count, row.documents_count,
     export_summary_share(row.share)]
  end

  def export_summary_xlsx_row_columns
    [xlsx_field(t('export_summaries.columns.customer_group'), &:customer_group), xlsx_field(t('export_summaries.columns.plant'), &:plant),
     xlsx_field(t('export_summaries.columns.country'), &:country), xlsx_field(t('export_summaries.columns.tons'), :decimal, &:tons),
     xlsx_field(t('export_summaries.columns.loadings'), :integer, &:loadings_count),
     xlsx_field(t('export_summaries.columns.documents'), :integer, &:documents_count),
     xlsx_field(t('export_summaries.columns.share'), :percentage, &:share)]
  end

  def export_summary_xlsx_document_columns(dashboard)
    [xlsx_field(t('export_summaries.columns.customer_group')) { |fact| dashboard.customer_group_label(fact.customer_group_id) },
     xlsx_field(t('export_summaries.documents.number'), &:number), xlsx_field(t('export_summaries.documents.trip_on'), :date, &:trip_on),
     xlsx_field(t('export_summaries.documents.manifest'), &:manifest_number), xlsx_field(t('export_summaries.documents.plate'), &:plate),
     xlsx_field(t('export_summaries.documents.origin')) { |fact| export_summary_document_origin(fact) },
     xlsx_field(t('export_summaries.columns.plant'), &:plant_label),
     xlsx_field(t('export_summaries.documents.recipient'), &:recipient_name),
     xlsx_field(t('export_summaries.columns.country')) { |fact| dashboard.country_label(fact.country) },
     xlsx_field(t('export_summaries.columns.tons'), :decimal, &:tons)]
  end
end
