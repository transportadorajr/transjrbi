class MaintenanceOrderItemForm < BaseForm
  attr_accessor :maintenance_order
  attr_writer :item

  delegate :id, :persisted?, to: :item

  class << self
    def for_item(item)
      form = new(maintenance_order: item.maintenance_order, **attributes_of(item))
      form.item = item
      form
    end
  end

  def item
    @item ||= items.new(tenant: maintenance_order.tenant)
  end

  def submit
    transaction do
      item.update!(item_attributes)
      MaintenanceOrders::RecalculateTotalsCommand.call(maintenance_order)
    end
  end

  private

  def tenant
    maintenance_order.tenant
  end
end
