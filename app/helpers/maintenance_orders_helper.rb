module MaintenanceOrdersHelper
  def maintenance_orders_menu(maintenance_order)
    menus = []

    menus << maintenance_order_show_menu(maintenance_order) if can?(:read, :maintenance_orders)
    menus << maintenance_order_edit_menu(maintenance_order) if can?(:update, :maintenance_orders) && maintenance_order.editable?

    menus
  end

  def maintenance_order_title(maintenance_order)
    t('maintenance_orders.title', number: maintenance_order.number, plate: maintenance_order.plate)
  end

  def maintenance_order_status_badge(maintenance_order)
    status_badge(maintenance_order.status_type_name, kind: maintenance_order.status_badge_kind)
  end

  def maintenance_order_opened_at(maintenance_order)
    l(maintenance_order.opened_at, format: :date_time)
  end

  def maintenance_order_vehicle_stopped(maintenance_order)
    t(maintenance_order.vehicle_stopped? ? 'maintenance_orders.vehicle_stopped.stopped' : 'maintenance_orders.vehicle_stopped.running')
  end

  def maintenance_order_equipment(maintenance_order)
    return maintenance_order.equipment_type_name unless maintenance_order.equipment_type_other?

    t('maintenance_orders.equipment_other', name: maintenance_order.equipment_other)
  end

  def maintenance_order_odometer(maintenance_order)
    return tax_value(nil) if maintenance_order.odometer_km.nil?

    t('maintenance_orders.km', distance: number_with_delimiter(maintenance_order.odometer_km))
  end

  def maintenance_order_hour_meter(maintenance_order)
    return tax_value(nil) if maintenance_order.hour_meter.nil?

    t('maintenance_orders.hours', hours: number_with_precision(maintenance_order.hour_meter, precision: 1))
  end

  def maintenance_order_text(text)
    return tax_value(nil) if text.blank?

    simple_format(text, class: 'mb-0')
  end

  def maintenance_order_filter_options(attribute)
    options_for_select(MaintenanceOrder.enum_options_for_select(attribute), params[attribute])
  end

  def maintenance_order_plate_options(plates)
    plates.map { |plate| [plate, plate] }
  end

  def maintenance_order_driver_options(drivers)
    drivers.map { |driver| [driver.driver_name.presence || driver.driver_code.to_s, driver.driver_code.to_s] }
  end

  def maintenance_order_form_url(maintenance_order_form)
    if maintenance_order_form.persisted?
      maintenance_order_path(maintenance_order_form.maintenance_order)
    else
      maintenance_orders_path
    end
  end

  def maintenance_order_form_cancel_path(maintenance_order_form)
    if maintenance_order_form.persisted?
      maintenance_order_path(maintenance_order_form.maintenance_order)
    else
      maintenance_orders_path
    end
  end

  def maintenance_order_form_submit_label(maintenance_order_form)
    t("helpers.submit.maintenance_order.#{maintenance_order_form.persisted? ? :update : :create}")
  end

  def maintenance_order_create_button
    create_button(t('maintenance_orders.index.new_maintenance_order')) if can?(:create, :maintenance_orders)
  end

  def maintenance_order_pdf_button(maintenance_order)
    link_to maintenance_order_path(maintenance_order, format: :pdf), class: 'btn btn-outline-danger btn-round', target: '_blank',
                                                                     rel: 'noopener', title: t('maintenance_orders.show.print') do
      safe_join([icon(:'file-earmark-pdf', class: 'me-md-2'), content_tag(:span, t('maintenance_orders.show.print'), class: 'd-none d-md-inline')])
    end
  end

  def maintenance_order_edit_button(maintenance_order)
    return unless can?(:update, :maintenance_orders) && maintenance_order.editable?

    link_to edit_maintenance_order_path(maintenance_order), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:pencil, class: 'me-2'), t('maintenance_orders.show.edit')])
    end
  end

  def maintenance_order_status_actions(maintenance_order)
    return unless can?(:update, :maintenance_orders)

    safe_join([
                maintenance_order_status_button(maintenance_order, :start, :'play-circle', 'btn-outline-primary'),
                maintenance_order_status_button(maintenance_order, :wait_parts, :'hourglass-split', 'btn-outline-secondary'),
                maintenance_order_finish_button(maintenance_order),
                maintenance_order_cancel_button(maintenance_order),
              ].compact)
  end

  def maintenance_order_closing_card(maintenance_order)
    render('maintenance_orders/closing', maintenance_order:) if maintenance_order.finished?
  end

  def maintenance_order_finished_at(maintenance_order)
    l(maintenance_order.finished_at, format: :date_time)
  end

  def maintenance_order_next_preventive(maintenance_order)
    return tax_value(nil) if maintenance_order.next_preventive_km.nil?

    t('maintenance_orders.km', distance: number_with_delimiter(maintenance_order.next_preventive_km))
  end

  private

  def maintenance_order_status_button(maintenance_order, event, icon_name, css_class)
    return unless maintenance_order.public_send(:"may_#{event}?")

    button_to public_send(:"#{event}_maintenance_order_path", maintenance_order), method: :patch,
                                                                                  class: "btn #{css_class} btn-round",
                                                                                  form_class: 'd-inline' do
      safe_join([icon(icon_name, class: 'me-2'), maintenance_order_event_label(maintenance_order, event)])
    end
  end

  def maintenance_order_event_label(maintenance_order, event)
    return t('maintenance_orders.actions.resume') if event == :start && maintenance_order.waiting_parts?

    t("maintenance_orders.actions.#{event}")
  end

  def maintenance_order_finish_button(maintenance_order)
    return unless maintenance_order.may_finish?

    link_to finishing_maintenance_order_path(maintenance_order), class: 'btn btn-success btn-round', data: { turbo_stream: true } do
      safe_join([icon(:'check2-circle', class: 'me-2'), t('maintenance_orders.actions.finish')])
    end
  end

  def maintenance_order_cancel_button(maintenance_order)
    return unless maintenance_order.may_cancel?

    button_to cancel_maintenance_order_path(maintenance_order), method: :patch, class: 'btn btn-outline-danger btn-round',
                                                                form_class: 'd-inline',
                                                                data: { turbo_confirm: t('maintenance_orders.actions.confirm_cancel') } do
      safe_join([icon(:'x-circle', class: 'me-2'), t('maintenance_orders.actions.cancel')])
    end
  end

  def maintenance_order_show_menu(maintenance_order)
    Menu.new(name: :show, record: maintenance_order, url: maintenance_order_path(maintenance_order), icon: :eye)
  end

  def maintenance_order_edit_menu(maintenance_order)
    Menu.new(name: :edit, record: maintenance_order, url: edit_maintenance_order_path(maintenance_order), icon: :pencil)
  end
end
