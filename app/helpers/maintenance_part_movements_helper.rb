module MaintenancePartMovementsHelper
  TYPE_BADGES = { entry: :success, exit: :danger, adjustment: :warning }.freeze

  def maintenance_stock_tabs(active)
    tabs = { parts: maintenance_parts_path, movements: maintenance_part_movements_path }

    tag.ul(class: 'nav nav-pills screen-tabs mb-3', id: 'maintenance_stock_tabs') do
      safe_join(tabs.map do |tab, path|
        tag.li(class: 'nav-item') do
          link_to t(tab, scope: 'maintenance_stock.tabs'), path, class: ['nav-link', { active: tab == active }],
                                                                 aria: { current: ('page' if tab == active) }
        end
      end)
    end
  end

  def maintenance_part_entry_button
    return unless can?(:create, :maintenance_parts)

    create_button(t('maintenance_part_movements.index.new_entry'), new_maintenance_part_movement_path(movement_type: :entry))
  end

  def maintenance_part_adjustment_button
    return unless can?(:create, :maintenance_parts)

    link_to new_maintenance_part_movement_path(movement_type: :adjustment), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:'arrow-repeat', class: 'me-2'), t('maintenance_part_movements.index.new_adjustment')])
    end
  end

  def maintenance_part_movement_kind(movement_form)
    movement_form.movement_type_adjustment? ? :adjustment : :entry
  end

  def maintenance_part_movement_title(movement_form)
    t("maintenance_part_movements.new.#{maintenance_part_movement_kind(movement_form)}_title")
  end

  def maintenance_part_movement_part_options(parts)
    options_for_select(parts.map { |part| [part.label, part.id] }, params[:maintenance_part_id])
  end

  def maintenance_part_movement_balance_options(parts)
    parts.map do |part|
      [t('maintenance_part_movements.form.part_option', part: part.label, balance: maintenance_stock_quantity(part.quantity, part.unit)),
       part.id.to_s]
    end
  end

  def maintenance_part_movement_type_badge(movement)
    status_badge(movement.movement_type_name, kind: TYPE_BADGES.fetch(movement.movement_type.to_sym))
  end

  def maintenance_part_movement_quantity(movement)
    quantity = maintenance_stock_quantity(movement.quantity, movement.maintenance_part.unit)
    movement.quantity.positive? ? "+#{quantity}" : quantity
  end

  def maintenance_stock_quantity(value, unit)
    [number_with_precision(value, precision: 3, strip_insignificant_zeros: true), unit].compact.join(' ')
  end

  def maintenance_part_movement_origin(movement)
    parts = [maintenance_part_movement_order_link(movement), maintenance_part_movement_invoice(movement), movement.supplier&.name,
             movement.notes].compact
    parts.any? ? safe_join(parts, ' · ') : t('tax.blank')
  end

  def maintenance_stock_badge(part)
    status_badge(maintenance_stock_quantity(part.quantity, part.unit), kind: part.quantity.negative? ? :danger : :secondary)
  end

  private

  def maintenance_part_movement_order_link(movement)
    return unless movement.maintenance_order

    link_to t('maintenance_part_movements.origin.order', number: movement.maintenance_order.number),
            maintenance_order_path(movement.maintenance_order)
  end

  def maintenance_part_movement_invoice(movement)
    t('maintenance_part_movements.origin.invoice', number: movement.invoice_number) if movement.invoice_number
  end
end
