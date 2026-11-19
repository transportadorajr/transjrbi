require 'rails_helper'

RSpec.describe MaintenanceOrders::SyncItemsCommand do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:) }
  let!(:synced_part) { create(:maintenance_order_part, maintenance_order:, description: 'LONA DE FREIO', total_cents: 34_000) }

  context 'with a part and a service written only to their own tables' do
    let!(:legacy_part) do
      create(:maintenance_order_part, maintenance_order:, description: 'FILTRO', notes: 'Trocar junto', total_cents: 5_000).tap { |part| part.item.delete }
    end
    let!(:legacy_service) do
      create(:maintenance_order_service, maintenance_order:, description: 'Solda', quoted_cents: 8_000, approved_cents: 7_500).tap do |service|
        service.item.delete
      end
    end

    it 'creates their items after the existing ones' do
      expect { described_class.call }.to change(MaintenanceOrderItem, :count).by(2)

      expect(maintenance_order.items.ordered.map { |item| [item.itemizable, item.description, item.notes, item.total_cents, item.position] }).to eq(
        [[synced_part, 'LONA DE FREIO', nil, 34_000, 1], [legacy_part, 'FILTRO', 'Trocar junto', 5_000, 2], [legacy_service, 'Solda', nil, 7_500, 3]],
      )
    end

    it 'does not duplicate the items when called again' do
      described_class.call

      expect { described_class.call }.not_to change(MaintenanceOrderItem, :count)
      expect(described_class.call).to eq(deleted: 0, updated: 0, created: 0)
    end
  end

  context 'with a part changed only on its own table' do
    before { synced_part.update_columns(description: 'LONA DE FREIO TRASEIRA', notes: 'Eixo 2', total_cents: 40_000) }

    it 'brings the shared columns to the item' do
      expect(described_class.call).to eq(deleted: 0, updated: 1, created: 0)

      expect(synced_part.item.reload).to have_attributes(description: 'LONA DE FREIO TRASEIRA', notes: 'Eixo 2', total_cents: 40_000, position: 1)
    end
  end

  context 'with a part removed only from its own table' do
    let!(:orphan_item) { synced_part.item }

    before { MaintenanceOrderPart.where(id: synced_part.id).delete_all }

    it 'removes the item left behind' do
      expect { described_class.call }.to change(MaintenanceOrderItem, :count).by(-1)

      expect(MaintenanceOrderItem.exists?(orphan_item.id)).to be(false)
    end
  end
end
