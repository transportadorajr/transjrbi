require 'rails_helper'

RSpec.describe MaintenanceOrderItem do
  let(:tenant) { create(:tenant) }
  let(:maintenance_order) { create(:maintenance_order, tenant:) }

  it 'requires a description' do
    item = build(:maintenance_order_item, maintenance_order:, description: '')

    expect(item).not_to be_valid
    expect(item.errors.full_messages).to eq(['Descrição não pode ficar em branco'])
  end

  it 'tells a part from a service even without a catalog link' do
    part = create(:maintenance_order_part, maintenance_order:, maintenance_part: nil)
    service = create(:maintenance_order_service, maintenance_order:, maintenance_service: nil)

    expect(part.item).to be_maintenance_order_part
    expect(service.item).to be_maintenance_order_service
    expect(described_class.maintenance_order_parts).to eq([part.item])
    expect(described_class.maintenance_order_services).to eq([service.item])
  end

  it 'copies the shared columns to the part it delegates to' do
    part = MaintenanceOrderPart.new(quantity: 2, unit_price_cents: 1_000)
    item = described_class.create!(tenant:, maintenance_order:, itemizable: part, description: 'FILTRO', notes: 'Trocar junto', total_cents: 2_000)

    expect(item.itemizable.reload).to have_attributes(tenant:, maintenance_order:, description: 'FILTRO', notes: 'Trocar junto', total_cents: 2_000)
  end

  it 'copies the description and notes to the service it delegates to' do
    service = MaintenanceOrderService.new(quoted_cents: 5_000)
    item = described_class.create!(tenant:, maintenance_order:, itemizable: service, description: 'Solda', notes: 'Urgente', total_cents: 5_000)

    expect(item.itemizable.reload).to have_attributes(tenant:, maintenance_order:, description: 'Solda', notes: 'Urgente')
  end

  it 'places each new item after the last one of the order' do
    first = create(:maintenance_order_part, maintenance_order:)
    second = create(:maintenance_order_service, maintenance_order:)
    other = create(:maintenance_order_part)

    expect([first.item.position, second.item.position, other.item.position]).to eq([1, 2, 1])
    expect(maintenance_order.items.ordered).to eq([first.item, second.item])
  end

  it 'removes the part along with the item' do
    part = create(:maintenance_order_part, maintenance_order:)

    expect { part.item.destroy! }.to change(MaintenanceOrderPart, :count).by(-1).and change(described_class, :count).by(-1)
  end

  it 'keeps a part already moved out of the stock' do
    stock_part = create(:maintenance_part, tenant:)
    part = create(:maintenance_order_part, maintenance_order:, maintenance_part: stock_part)
    create(:maintenance_part_movement, tenant:, maintenance_part: stock_part, maintenance_order:, maintenance_order_part: part)

    expect { part.item.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(described_class.exists?(part.item.id)).to be(true)
    expect(MaintenanceOrderPart.exists?(part.id)).to be(true)
  end
end
