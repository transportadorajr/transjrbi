require 'rails_helper'

RSpec.describe MaintenanceOrderService do
  it 'exposes the quoted and approved values as money' do
    service = build(:maintenance_order_service, quoted_cents: 45_000, approved_cents: nil)

    expect(service.quoted).to eq(Money.from_cents(45_000))
    expect(service.approved).to be_nil
  end

  it 'is worth the approved value, falling back to the quoted value' do
    expect(build(:maintenance_order_service, quoted_cents: 45_000, approved_cents: 42_000).value_cents).to eq(42_000)
    expect(build(:maintenance_order_service, quoted_cents: 45_000, approved_cents: nil).value_cents).to eq(45_000)
    expect(build(:maintenance_order_service, quoted_cents: nil, approved_cents: nil).value_cents).to eq(0)
  end
end
