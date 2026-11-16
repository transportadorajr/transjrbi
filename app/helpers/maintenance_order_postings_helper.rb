module MaintenanceOrderPostingsHelper
  def maintenance_order_posting_button(maintenance_order)
    return unless can?(:update, :maintenance_orders) && maintenance_order.finished?

    link_to edit_maintenance_order_posting_path(maintenance_order), class: 'btn btn-outline-primary btn-round',
                                                                    data: { turbo_stream: true } do
      safe_join([icon(:'journal-check', class: 'me-2'), maintenance_order_posting_action(maintenance_order)])
    end
  end

  def maintenance_order_posting_card(maintenance_order)
    render('maintenance_orders/posting', maintenance_order:) if maintenance_order.finished?
  end

  def maintenance_order_posted_on(maintenance_order)
    return tax_value(nil) if maintenance_order.posted_on.nil?

    l(maintenance_order.posted_on)
  end

  def maintenance_order_posting_verified(maintenance_order)
    t(maintenance_order.posting_verified? ? 'maintenance_order_postings.verified.yes' : 'maintenance_order_postings.verified.no')
  end

  def maintenance_order_posting_filter_options
    options_for_select(MaintenanceOrder::POSTINGS.map { |posting| [t(posting, scope: 'maintenance_order_postings.filter'), posting] },
                       params[:posting])
  end

  def maintenance_order_pdf_posting_fields(maintenance_order)
    [
      [MaintenanceOrder.human_attribute_name(:posted_on), maintenance_order_posted_on(maintenance_order)],
      [MaintenanceOrder.human_attribute_name(:posted_by), tax_value(maintenance_order.posted_by&.name)],
      [MaintenanceOrder.human_attribute_name(:atua_order_number), tax_value(maintenance_order.atua_order_number)],
      [MaintenanceOrder.human_attribute_name(:posting_verified), maintenance_order_posting_verified(maintenance_order)],
    ]
  end

  private

  def maintenance_order_posting_action(maintenance_order)
    t(maintenance_order.posted? ? 'maintenance_order_postings.actions.edit' : 'maintenance_order_postings.actions.post')
  end
end
