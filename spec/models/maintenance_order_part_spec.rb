require 'rails_helper'

RSpec.describe MaintenanceOrderPart do
  it 'requires a description and a positive quantity' do
    part = build(:maintenance_order_part, description: '', quantity: 0)

    expect(part).not_to be_valid
    expect(part.errors.full_messages).to contain_exactly('Descrição não pode ficar em branco', 'Quantidade deve ser maior que 0')
  end

  it 'exposes the prices as money and translates the source' do
    part = build(:maintenance_order_part, unit_price_cents: 8_500, total_cents: 34_000, source_type: 'purchase')

    expect(part.unit_price).to eq(Money.from_cents(8_500))
    expect(part.total).to eq(Money.from_cents(34_000))
    expect(part.source_type_name).to eq('Compra direta')
  end
end
