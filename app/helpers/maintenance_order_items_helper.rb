module MaintenanceOrderItemsHelper
  ITEM_ICONS = { 'part' => :'box-seam', 'labor' => :'person-gear', 'service' => :truck }.freeze

  def maintenance_order_item_modal_title(item_form)
    t("maintenance_order_items.#{maintenance_order_item_kind(item_form)}.#{item_form.persisted? ? :edit_title : :new_title}")
  end

  def maintenance_order_item_icon(item_form)
    ITEM_ICONS.fetch(maintenance_order_item_kind(item_form))
  end

  def maintenance_order_form_errors(form)
    return if form.errors.empty?

    content_tag(:div, form.errors.full_messages.to_sentence, class: 'alert alert-danger', role: :alert)
  end

  def maintenance_order_item_form_url(item_form)
    kind = maintenance_order_item_kind(item_form)
    order = item_form.maintenance_order

    if item_form.persisted?
      public_send(:"maintenance_order_#{kind}_path", order, item_form.item)
    else
      public_send(:"maintenance_order_#{kind.pluralize}_path", order)
    end
  end

  def maintenance_order_item_fields_partial(item_form)
    "maintenance_order_#{maintenance_order_item_kind(item_form).pluralize}/fields"
  end

  def maintenance_order_item_submit_label(item_form)
    t("helpers.submit.maintenance_order_item.#{item_form.persisted? ? :update : :create}")
  end

  def maintenance_order_item_add_button(maintenance_order, kind)
    return unless can?(:update, :maintenance_orders) && maintenance_order.editable?

    link_to public_send(:"new_maintenance_order_#{kind}_path", maintenance_order),
            class: 'btn btn-sm btn-outline-primary btn-round', data: { turbo_stream: true } do
      safe_join([icon(:'plus-circle', class: 'me-1'), t("maintenance_order_items.#{kind}.add")])
    end
  end

  def maintenance_order_items_menu(item)
    return [] unless can?(:update, :maintenance_orders) && item.maintenance_order.editable?

    kind = item.model_name.element.delete_prefix('maintenance_order_')
    [maintenance_order_item_edit_menu(item, kind), maintenance_order_item_destroy_menu(item, kind)]
  end

  def maintenance_order_part_quantity(part)
    safe_join([number_with_precision(part.quantity, precision: 3, strip_insignificant_zeros: true), part.unit].compact, ' ')
  end

  def maintenance_order_labor_period(labor)
    return tax_value(nil) if labor.start_time.blank?

    t('maintenance_order_items.labor.period', start: labor.start_time.strftime('%H:%M'), end: labor.end_time.strftime('%H:%M'))
  end

  def maintenance_order_labor_hours(hours)
    return tax_value(nil) if hours.nil?

    t('maintenance_orders.hours', hours: number_with_precision(hours, precision: 2, strip_insignificant_zeros: true))
  end

  private

  def maintenance_order_item_kind(item_form)
    item_form.class.model_name.param_key.delete_prefix('maintenance_order_')
  end

  def maintenance_order_item_edit_menu(item, kind)
    Menu.new(name: :edit, record: item, url: public_send(:"edit_maintenance_order_#{kind}_path", item.maintenance_order, item),
             icon: :pencil, data: { turbo_stream: true })
  end

  def maintenance_order_item_destroy_menu(item, kind)
    Menu.new(
      name: :destroy,
      record: item,
      url: public_send(:"maintenance_order_#{kind}_path", item.maintenance_order, item),
      icon: :'x-circle',
      data: {
        turbo_confirm: t("maintenance_order_items.#{kind}.confirm_destroy"),
        turbo_method: :delete,
      },
    )
  end
end
