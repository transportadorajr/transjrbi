require 'rails_helper'

RSpec.describe MaintenanceOrders::DeductStockCommand do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant:) }
  let!(:part) { create(:maintenance_part, tenant:, quantity: 10) }
  let!(:order) { create(:maintenance_order, tenant:, status_type: :finished, finished_at: Time.zone.local(2026, 11, 17, 15)) }
  let!(:stock_part) { create(:maintenance_order_part, maintenance_order: order, maintenance_part: part, quantity: 3, source_type: :stock) }
  let!(:purchased_part) do
    create(:maintenance_order_part, maintenance_order: order, maintenance_part: part, quantity: 1, source_type: :purchase)
  end
  let!(:free_part) { create(:maintenance_order_part, maintenance_order: order, quantity: 2, source_type: :stock) }

  it 'takes out of the stock only the registered stock parts' do
    movements = described_class.call(order, created_by: user)

    expect(movements.size).to eq(1)
    expect(movements.first).to have_attributes(maintenance_part: part, maintenance_order: order, maintenance_order_part: stock_part,
                                               movement_type: 'exit', quantity: -3, balance: 7, moved_on: Date.new(2026, 11, 17),
                                               created_by: user)
    expect(part.reload.quantity).to eq(7)
  end

  it 'does not take a part out twice when run again' do
    described_class.call(order)

    expect { expect(described_class.call(order)).to eq([]) }.not_to change(MaintenancePartMovement, :count)
    expect(part.reload.quantity).to eq(7)
  end
end
