require 'rails_helper'

RSpec.describe MaintenanceParts::RegisterMovementCommand do
  let(:tenant) { create(:tenant) }
  let!(:part) { create(:maintenance_part, tenant:, quantity: 4, unit_price_cents: 8_500) }

  it 'registers an entry raising the balance and updating the suggested price' do
    movement = described_class.call(part, movement_type: :entry, quantity: 6, moved_on: Date.new(2026, 11, 17), unit_cost_cents: 9_000)

    expect(movement).to have_attributes(tenant:, movement_type: 'entry', quantity: 6, balance: 10, unit_cost_cents: 9_000)
    expect(part.reload).to have_attributes(quantity: 10, unit_price_cents: 9_000)
  end

  it 'keeps the suggested price on an entry without cost' do
    described_class.call(part, movement_type: :entry, quantity: 1, moved_on: Date.new(2026, 11, 17))

    expect(part.reload).to have_attributes(quantity: 5, unit_price_cents: 8_500)
  end

  it 'lets an exit take the balance below zero' do
    movement = described_class.call(part, movement_type: :exit, quantity: -7, moved_on: Date.new(2026, 11, 17), unit_cost_cents: 1)

    expect(movement).to have_attributes(quantity: -7, balance: -3)
    expect(part.reload).to have_attributes(quantity: -3, unit_price_cents: 8_500)
  end
end
