require 'rails_helper'

RSpec.describe MaintenanceOrderMechanic do
  let(:maintenance_order) { create(:maintenance_order) }
  let(:mechanic) { create(:workshop_employee, tenant: maintenance_order.tenant) }

  it 'does not assign the same mechanic twice to an order' do
    create(:maintenance_order_mechanic, maintenance_order:, workshop_employee: mechanic)
    duplicate = build(:maintenance_order_mechanic, maintenance_order:, workshop_employee: mechanic)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:workshop_employee_id]).to eq(['já está em uso'])
  end

  it 'assigns the same mechanic to different orders' do
    create(:maintenance_order_mechanic, maintenance_order:, workshop_employee: mechanic)
    other_order = create(:maintenance_order, tenant: maintenance_order.tenant)

    expect(build(:maintenance_order_mechanic, maintenance_order: other_order, workshop_employee: mechanic)).to be_valid
  end
end
