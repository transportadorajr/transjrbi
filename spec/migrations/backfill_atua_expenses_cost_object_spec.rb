require 'rails_helper'
require Rails.root.join('db/migrate/20261015132331_backfill_atua_expenses_cost_object')

RSpec.describe BackfillAtuaExpensesCostObject do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
  let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, vehicle_code: 812) }
  let!(:stranger_truck) { create(:atua_vehicle, tenant: other_tenant, plate: 'EXU0F72') }
  let!(:toll) { create(:atua_expense, tenant:, transport_document_code: 80_512, plate: 'EXU0F72') }
  let!(:tire) { create(:atua_expense, tenant:, plate: 'EXU0F72') }
  let!(:rent) { create(:atua_expense, tenant:, plate: nil) }
  let!(:stranger) { create(:atua_expense, tenant: other_tenant, plate: 'EXU0F72') }

  it 'links the imported expenses of every tenant to their freights and vehicles' do
    migration.up

    expect(toll.reload.cost_object).to eq(transport_document)
    expect(tire.reload.cost_object).to eq(truck)
    expect(rent.reload.cost_object).to be_nil
    expect(stranger.reload.cost_object).to eq(stranger_truck)
  end

  it 'can run again without changing the links' do
    migration.up

    expect { migration.up }.not_to(change { Atua::Expense.order(:id).pluck(:cost_object_type, :cost_object_id, :updated_at) })
  end
end
