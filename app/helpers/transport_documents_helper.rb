module TransportDocumentsHelper
  TOLL_BADGE_KINDS = { in_freight: :primary, outside_freight: :info, none: :secondary }.freeze

  def transport_documents_menu(transport_document)
    menus = []

    menus << transport_document_show_menu(transport_document) if can?(:read, :transport_documents)

    menus
  end

  def transport_document_distance(transport_document)
    distance = tax_decimal(transport_document.distance_km)
    return distance unless transport_document.distance_adjusted_at

    key = transport_document.distance_edited_at ? 'edited_distance' : 'original_distance'
    original = t("transport_documents.show.#{key}", distance: tax_decimal(transport_document.original_distance_km))
    safe_join([distance, content_tag(:small, original, class: 'd-block text-muted')], ' ')
  end

  def transport_document_edit_distance_button(transport_document)
    return unless can?(:update, :transport_documents)

    link_to edit_transport_document_distance_path(transport_document), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('transport_documents.show.edit_distance')
    end
  end

  def transport_document_resync_button(transport_document)
    return unless can?(:update, :transport_documents) && Atua.enabled?(current_user.tenant) && transport_document.issued_at

    date = l(transport_document.issued_at.to_date)
    button_to resync_transport_document_path(transport_document), class: 'btn btn-outline-primary btn-round', form_class: 'd-inline-block',
                                                                  data: { turbo_confirm: t('transport_documents.show.confirm_resync', date:) } do
      concat icon(:'arrow-repeat', class: 'me-2')
      concat t('transport_documents.show.resync')
    end
  end

  def transport_document_customer_options(customers)
    customers.map do |customer|
      [[customer.name, customer.document].compact_blank.join(' - ').presence || customer.code.to_s, customer.code.to_s]
    end
  end

  def transport_document_route(transport_document)
    t('transport_documents.route',
      origin: tax_city(transport_document.origin_city, transport_document.origin_state),
      destination: tax_city(transport_document.destination_city, transport_document.destination_state))
  end

  def transport_document_mobile_details(transport_document)
    details = [[Atua::TransportDocument.human_attribute_name(:document_kind), transport_document_kind_name(transport_document)],
               [Atua::TransportDocument.human_attribute_name(:posted_on), tax_date(transport_document.posted_on)],
               [Atua::TransportDocument.human_attribute_name(:gross), tax_money(transport_document.freight)]]
    details << [Atua::TransportDocument.human_attribute_name(:net), freight_money(transport_document.net_cents)] if can?(:read, :freight_expenses)

    details + [[Atua::TransportDocument.human_attribute_name(:driver_name), tax_value(transport_document.driver_display_name)],
               [Atua::TransportDocument.human_attribute_name(:customer_group), tax_value(transport_document.customer_group_name)],
               [Atua::TransportDocument.human_attribute_name(:origin), tax_city(transport_document.origin_city, transport_document.origin_state)],
               [Atua::TransportDocument.human_attribute_name(:destination),
                tax_city(transport_document.destination_city, transport_document.destination_state)]]
  end

  def transport_document_title(key, transport_document)
    t(key, kind: transport_document_kind_name(transport_document), number: transport_document.number)
  end

  def transport_document_kind_name(transport_document)
    t(transport_document.document_kind.presence || 'cte', scope: 'transport_documents.document_kinds')
  end

  def transport_document_kind(transport_document)
    return t('tax.blank') if transport_document.document_kind.blank?

    kind = t(transport_document.document_kind, scope: 'transport_documents.document_kinds')
    return kind unless transport_document.vehicle_sale?

    safe_join([kind, status_badge(t('transport_documents.vehicle_sale'), kind: :warning)], ' ')
  end

  def transport_document_party(name, document)
    return t('tax.blank') if name.blank?

    safe_join([content_tag(:span, name, class: 'd-block'), (content_tag(:span, document, class: 'text-muted text-small d-block') if document.present?)], ' ')
  end

  def transport_document_toll(transport_document)
    content_tag :span, class: 'd-inline-flex flex-wrap align-items-center gap-2' do
      safe_join([tax_money(transport_document.toll), transport_document_toll_badge(transport_document)], ' ')
    end
  end

  def transport_document_toll_badge(transport_document)
    placement = transport_document.toll_placement

    status_badge(t(placement, scope: 'transport_documents.toll_placements'), kind: TOLL_BADGE_KINDS.fetch(placement))
  end

  def transport_document_empty_legs(empty_legs)
    return content_tag(:p, t('transport_documents.show.no_empty_leg'), class: 'text-body-secondary mb-0') if empty_legs.none?

    content_tag(:div, render(partial: 'transport_documents/empty_leg', collection: empty_legs), class: 'd-flex flex-column gap-4')
  end

  def transport_document_expenses(transport_document, expenses, complements, total)
    return if expenses.nil?

    render 'transport_documents/expenses/card', transport_document:, expenses:, complements:, total:
  end

  def transport_document_expenses_table(transport_document, expenses, complements, total)
    if expenses.none? && complements.none? && transport_document.complement_transfer.zero?
      return content_tag(:p, t('transport_documents.show.no_expenses'), class: 'text-body-secondary mb-0')
    end

    render 'transport_documents/expenses/table', transport_document:, expenses:, complements:, total:
  end

  def transport_document_complemented(transport_document)
    original = transport_document.complemented_transport_document
    return unless original

    safe_join([content_tag(:dt, Atua::TransportDocument.human_attribute_name(:complemented_transport_document), class: 'col-12 col-md-5'),
               content_tag(:dd, freight_expense_transport_document(original), class: 'col-12 col-md-7')])
  end

  def transport_document_complement_credit_name(complement)
    safe_join([t('transport_documents.expenses.complement_credit_html', number: freight_expense_transport_document(complement)),
               status_badge(t('transport_documents.expenses.complement_kind'), kind: :success)], ' ')
  end

  def transport_document_complement_transfer_row(transport_document)
    return if transport_document.complement_transfer.zero?

    render 'transport_documents/expenses/complement_transfer_row', transport_document:
  end

  def transport_document_freight_expenses(freight_expenses, total)
    return if freight_expenses.blank?

    render 'transport_documents/freight_expenses/card', freight_expenses:, total:
  end

  def transport_document_freight_expense_row(freight_expense)
    return render('transport_documents/freight_expenses/export_insurance_rows', freight_expense:) if freight_expense.export_insurance?

    render 'transport_documents/freight_expenses/expense_row', freight_expense:
  end

  def transport_document_manifests_table(manifests)
    return render('shared/no_content') if manifests.none?

    render 'transport_documents/manifests/table', manifests:
  end

  def transport_document_manifest_number(manifest)
    return manifest.number unless can?(:read, :manifests)

    link_to manifest.number, manifest_path(manifest), class: 'fw-semibold text-decoration-none'
  end

  def transport_documents_pdf_report(transport_documents)
    PdfReport.new(title: t('transport_documents.index.pdf.header'), columns: transport_documents_pdf_columns,
                  rows: transport_documents.map { |transport_document| transport_document_pdf_row(transport_document) })
  end

  def transport_documents_pdf_columns
    columns = [pdf_column(Atua::TransportDocument.human_attribute_name(:number)),
               pdf_column(Atua::TransportDocument.human_attribute_name(:document_kind)), pdf_column(Atua::TransportDocument.human_attribute_name(:sender), '2fr'),
               pdf_column(Atua::TransportDocument.human_attribute_name(:posted_on)), pdf_column(Atua::TransportDocument.human_attribute_name(:origin), '1.5fr'),
               pdf_column(Atua::TransportDocument.human_attribute_name(:destination), '1.5fr'),
               pdf_column(Atua::TransportDocument.human_attribute_name(:plate)), pdf_column(Atua::TransportDocument.human_attribute_name(:customer_group), '2fr'),
               pdf_column(Atua::TransportDocument.human_attribute_name(:driver_name), '2fr'),
               pdf_column(Atua::TransportDocument.human_attribute_name(:gross), align: :right)]
    columns << pdf_column(Atua::TransportDocument.human_attribute_name(:net), align: :right) if can?(:read, :freight_expenses)

    columns
  end

  def transport_document_pdf_row(transport_document)
    row = [transport_document.number, transport_document_kind_name(transport_document), tax_value(transport_document.sender_name), tax_date(transport_document.posted_on),
           tax_city(transport_document.origin_city, transport_document.origin_state),
           tax_city(transport_document.destination_city, transport_document.destination_state), tax_value(transport_document.plate),
           tax_value(transport_document.customer_group_name), tax_value(transport_document.driver_display_name), tax_money(transport_document.freight)]
    row << freight_money(transport_document.net_cents) if can?(:read, :freight_expenses)

    row
  end

  private

  def transport_document_show_menu(transport_document)
    Menu.new(name: :show, record: transport_document, url: transport_document_path(transport_document), icon: :eye)
  end
end
