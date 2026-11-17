require 'rails_helper'

RSpec.describe MaintenanceService do
  let(:tenant) { create(:tenant) }
  let!(:grinding) { create(:maintenance_service, tenant:, code: 'RET-01', description: 'RETÍFICA DE MOTOR') }
  let!(:alignment) { create(:maintenance_service, tenant:, description: 'ALINHAMENTO', active: false) }

  it 'filters the services by code or description and by status' do
    expect(tenant.maintenance_services.by_term('ret-')).to contain_exactly(grinding)
    expect(tenant.maintenance_services.by_status('inactive')).to contain_exactly(alignment)
    expect(tenant.maintenance_services.active).to contain_exactly(grinding)
  end

  it 'validates the description per tenant' do
    expect(build(:maintenance_service, tenant:, description: 'ALINHAMENTO')).not_to be_valid
    expect(build(:maintenance_service, description: 'ALINHAMENTO')).to be_valid
  end
end
