module MaintenanceOrderPdfHelper
  SIGNATURES = %i[supervisor].freeze

  def maintenance_order_pdf_title(maintenance_order)
    t('maintenance_orders.show.pdf.header', number: maintenance_order.number, company: maintenance_order.tenant.trade_name)
  end

  def maintenance_order_pdf_subtitle(maintenance_order)
    t('maintenance_orders.show.pdf.subtitle', plate: maintenance_order.plate, status: maintenance_order.status_type_name)
  end

  def maintenance_order_pdf_vehicle_fields(maintenance_order)
    [
      [MaintenanceOrder.human_attribute_name(:number), maintenance_order.number],
      [MaintenanceOrder.human_attribute_name(:opened_at), maintenance_order_opened_at(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:plate), maintenance_order.plate],
      [MaintenanceOrder.human_attribute_name(:equipment_type), maintenance_order_equipment(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:odometer_km), maintenance_order_odometer(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:hour_meter), maintenance_order_hour_meter(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:driver_name), tax_value(maintenance_order.driver_name)],
      [MaintenanceOrder.human_attribute_name(:supervisor), tax_value(maintenance_order.supervisor&.name)],
    ]
  end

  def maintenance_order_pdf_classification_fields(maintenance_order)
    [
      [MaintenanceOrder.human_attribute_name(:maintenance_type), maintenance_order.maintenance_type_name],
      [MaintenanceOrder.human_attribute_name(:priority_type), maintenance_order.priority_type_name],
      [MaintenanceOrder.human_attribute_name(:vehicle_stopped), maintenance_order_vehicle_stopped(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:execution_place_type), maintenance_order.execution_place_type_name],
      [MaintenanceOrder.human_attribute_name(:affected_system_type), maintenance_order.affected_system_type_name],
      [MaintenanceOrder.human_attribute_name(:status_type), maintenance_order.status_type_name],
    ]
  end

  def maintenance_order_pdf_closing_fields(maintenance_order)
    [
      [MaintenanceOrder.human_attribute_name(:finished_at), maintenance_order_pdf_finished_at(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:release_test_type), maintenance_order_pdf_release_test(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:next_preventive_km), maintenance_order_next_preventive(maintenance_order)],
    ]
  end

  def maintenance_order_pdf_total_fields(maintenance_order, labor_hours)
    [
      [MaintenanceOrder.human_attribute_name(:parts_total), tax_money(maintenance_order.parts_total)],
      [MaintenanceOrder.human_attribute_name(:services_total), tax_money(maintenance_order.services_total)],
      [MaintenanceOrder.human_attribute_name(:labor_hours), maintenance_order_labor_hours(labor_hours)],
      [MaintenanceOrder.human_attribute_name(:total), tax_money(maintenance_order.total)],
    ]
  end

  def maintenance_order_pdf_text(text)
    text.presence || t('tax.blank')
  end

  def maintenance_order_pdf_parts(parts)
    PdfReport.new(
      title: t('maintenance_orders.show.parts'),
      columns: [pdf_column(MaintenanceOrderPart.human_attribute_name(:code)), pdf_column(MaintenanceOrderPart.human_attribute_name(:description), '1fr'),
                pdf_column(MaintenanceOrderPart.human_attribute_name(:quantity), align: :right),
                pdf_column(MaintenanceOrderPart.human_attribute_name(:source_type)),
                pdf_column(MaintenanceOrderPart.human_attribute_name(:document_number)),
                pdf_column(MaintenanceOrderPart.human_attribute_name(:unit_price), align: :right),
                pdf_column(MaintenanceOrderPart.human_attribute_name(:total), align: :right)],
      rows: parts.map do |part|
        [tax_value(part.code), part.description, maintenance_order_part_quantity(part), part.source_type_name,
         tax_value(part.document_number), tax_money(part.unit_price), tax_money(part.total)]
      end,
    )
  end

  def maintenance_order_pdf_labors(labors)
    PdfReport.new(
      title: t('maintenance_orders.show.labors'),
      columns: [pdf_column(MaintenanceOrderLabor.human_attribute_name(:workshop_employee)),
                pdf_column(MaintenanceOrderLabor.human_attribute_name(:worked_on)), pdf_column(t('maintenance_orders.show.period')),
                pdf_column(MaintenanceOrderLabor.human_attribute_name(:hours), align: :right),
                pdf_column(MaintenanceOrderLabor.human_attribute_name(:activity), '1fr')],
      rows: labors.map do |labor|
        [labor.workshop_employee.name, l(labor.worked_on), maintenance_order_labor_period(labor),
         maintenance_order_labor_hours(labor.hours), tax_value(labor.activity)]
      end,
    )
  end

  def maintenance_order_pdf_services(services)
    PdfReport.new(
      title: t('maintenance_orders.show.services'),
      columns: [pdf_column(MaintenanceOrderService.human_attribute_name(:supplier)),
                pdf_column(MaintenanceOrderService.human_attribute_name(:description), '1fr'),
                pdf_column(MaintenanceOrderService.human_attribute_name(:quote_number)),
                pdf_column(MaintenanceOrderService.human_attribute_name(:quoted), align: :right),
                pdf_column(MaintenanceOrderService.human_attribute_name(:approved), align: :right),
                pdf_column(MaintenanceOrderService.human_attribute_name(:approved_by_name)),
                pdf_column(MaintenanceOrderService.human_attribute_name(:invoice_number))],
      rows: services.map do |service|
        [service.supplier.name, service.description, tax_value(service.quote_number), tax_money(service.quoted),
         tax_money(service.approved), tax_value(service.approved_by_name), tax_value(service.invoice_number)]
      end,
    )
  end

  def maintenance_order_pdf_items(report, empty_message)
    return typst_paragraph(empty_message) if report.empty?

    render 'shared/pdf_table', report:
  end

  def maintenance_order_pdf_signatures(maintenance_order)
    SIGNATURES.map do |signature|
      [t(signature, scope: 'maintenance_orders.show.pdf.signatures'), maintenance_order.public_send(signature)&.name]
    end
  end

  private

  def maintenance_order_pdf_release_test(maintenance_order)
    return tax_value(nil) if maintenance_order.release_test_type.nil?

    maintenance_order.release_test_type_name
  end

  def maintenance_order_pdf_finished_at(maintenance_order)
    return tax_value(nil) if maintenance_order.finished_at.nil?

    maintenance_order_finished_at(maintenance_order)
  end
end
