require 'rails_helper'
require Rails.root.join('db/migrate/20261119125158_backfill_maintenance_order_items')

RSpec.describe BackfillMaintenanceOrderItems do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:) }
  let!(:other_order) { create(:maintenance_order, tenant:) }
  let!(:service) { create(:maintenance_order_service, maintenance_order:, description: 'Solda', notes: 'Urgente', quoted_cents: 8_000, approved_cents: nil) }
  let!(:part) { create(:maintenance_order_part, maintenance_order:, description: 'FILTRO', total_cents: 5_000) }
  let!(:other_part) { create(:maintenance_order_part, maintenance_order: other_order, description: 'ÓLEO', total_cents: 1_000) }

  before { MaintenanceOrderItem.delete_all }

  it 'creates one item per part and service, parts first' do
    expect { migration.up }.to change(MaintenanceOrderItem, :count).by(3)

    expect(maintenance_order.items.ordered.map { |item| [item.itemizable, item.tenant, item.description, item.notes, item.total_cents, item.position] }).to eq(
      [[part, tenant, 'FILTRO', nil, 5_000, 1], [service, tenant, 'Solda', 'Urgente', 8_000, 2]],
    )
    expect(other_order.items.map { |item| [item.itemizable, item.position] }).to eq([[other_part, 1]])
  end

  it 'can run again without duplicating the items' do
    migration.up

    expect { migration.up }.not_to change(MaintenanceOrderItem, :count)
  end

  it 'keeps the totals of the order' do
    migration.up
    MaintenanceOrders::RecalculateTotalsCommand.call(maintenance_order)

    expect(maintenance_order.reload).to have_attributes(parts_total_cents: 5_000, services_total_cents: 8_000, total_cents: 13_000)
  end
end
