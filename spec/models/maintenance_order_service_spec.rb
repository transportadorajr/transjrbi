require 'rails_helper'

RSpec.describe MaintenanceOrderService do
  it 'requires a description' do
    service = build(:maintenance_order_service, description: '')

    expect(service).not_to be_valid
    expect(service.errors.full_messages).to eq(['Serviço não pode ficar em branco'])
  end

  it 'exposes the quoted and approved values as money' do
    service = build(:maintenance_order_service, quoted_cents: 45_000, approved_cents: nil)

    expect(service.quoted).to eq(Money.from_cents(45_000))
    expect(service.approved).to be_nil
  end
end
