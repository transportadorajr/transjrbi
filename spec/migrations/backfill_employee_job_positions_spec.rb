require 'rails_helper'
require Rails.root.join('db/migrate/20261123210608_backfill_employee_job_positions')

RSpec.describe BackfillEmployeeJobPositions do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:jose) { create(:employee, tenant:, legal_id: '52998224725') }
  let!(:ana) { create(:employee, tenant:, legal_id: '11144477735') }
  let!(:carlos) { create(:employee, tenant:, legal_id: '39053344705') }
  let!(:stranger) { create(:employee, tenant: other_tenant, legal_id: '52998224725') }

  before do
    {
      jose => 'MOTORISTA', ana => ' motorista ', carlos => nil, stranger => 'MOTORISTA'
    }.each { |employee, role| Employee.where(id: employee.id).update_all(['role = ?', role]) }
  end

  it 'registers the typed roles as job positions of each tenant and links the employees' do
    expect { 2.times { migration.up } }.to change(JobPosition, :count).by(2)

    expect(JobPosition.order(:tenant_id).pluck(:tenant_id, :name)).to eq([[tenant.id, 'MOTORISTA'], [other_tenant.id, 'MOTORISTA']])
    expect(JobPosition.all).to all(be_activated)
    expect([jose, ana, carlos, stranger].map { |employee| employee.reload.job_position&.slice(:tenant_id, :name) }).to eq(
      [
        { 'tenant_id' => tenant.id, 'name' => 'MOTORISTA' },
        { 'tenant_id' => tenant.id, 'name' => 'MOTORISTA' },
        nil,
        { 'tenant_id' => other_tenant.id, 'name' => 'MOTORISTA' },
      ],
    )
  end
end
