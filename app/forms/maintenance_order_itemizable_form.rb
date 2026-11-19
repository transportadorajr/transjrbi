class MaintenanceOrderItemizableForm < MaintenanceOrderItemForm
  delegate :itemizable, to: :item
  delegate :id, to: :itemizable

  class << self
    def for_item(item)
      form = new(maintenance_order: item.maintenance_order, description: item.description, notes: item.notes,
                 **attributes_of(item.itemizable))
      form.item = item
      form
    end
  end

  def item
    @item ||= maintenance_order.items.new(tenant:, itemizable: itemizable_class.new)
  end

  private

  def save_item
    itemizable.assign_attributes(itemizable_attributes)
    item.update!(description:, notes:, total_cents:)
  end
end
