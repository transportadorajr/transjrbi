require 'rails_helper'

RSpec.describe MaintenanceOrderPart do
  it 'requires a positive quantity' do
    part = build(:maintenance_order_part, quantity: 0)

    expect(part).not_to be_valid
    expect(part.errors.full_messages).to eq(['Quantidade deve ser maior que 0'])
  end

  it 'exposes the unit price as money and translates the source' do
    part = build(:maintenance_order_part, unit_price_cents: 8_500, source_type: 'purchase')

    expect(part.unit_price).to eq(Money.from_cents(8_500))
    expect(part.source_type_name).to eq('Compra direta')
  end

  it 'reaches its order item' do
    part = create(:maintenance_order_part, description: 'LONA DE FREIO', total_cents: 34_000)

    expect(part.item).to have_attributes(itemizable: part, description: 'LONA DE FREIO', total_cents: 34_000)
  end
end
