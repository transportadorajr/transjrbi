require 'rails_helper'
require Rails.root.join('db/migrate/20261123210613_add_job_positions_resource')

RSpec.describe AddJobPositionsResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the job positions resource' do
    it 'creates the writable job positions resource once' do
      expect { 2.times { migration.up } }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['job_positions', 'Cargos', true]])
    end
  end

  context 'with users allowed to the employees' do
    let!(:employees) { create(:resource, name: 'Funcionários', slug: 'employees') }
    let!(:reader) { create(:user) }
    let!(:writer) { create(:user) }

    before do
      create(:access, user: reader, tenant: reader.tenant, resource: employees, reads: true)
      create(:access, user: writer, tenant: writer.tenant, resource: employees, reads: true, creates: true)
    end

    it 'gives them the same access to the job positions' do
      2.times { migration.up }

      job_positions = Resource.find_by!(slug: 'job_positions')
      expect(Access.where(resource: job_positions).pluck(:user_id, :tenant_id, :reads, :creates))
        .to contain_exactly([reader.id, reader.tenant_id, true, false], [writer.id, writer.tenant_id, true, true])
    end

    it 'removes the resource and its accesses when rolling back' do
      migration.up

      expect { migration.down }.to change(Resource, :count).by(-1).and change(Access, :count).by(-2)
    end
  end
end
