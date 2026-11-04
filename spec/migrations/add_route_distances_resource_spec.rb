require 'rails_helper'
require Rails.root.join('db/migrate/20261104224809_add_route_distances_resource')

RSpec.describe AddRouteDistancesResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the route distances resource' do
    it 'creates the writable route distances resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['route_distances', 'Trechos de km', true]])
    end

    it 'can run again without duplicating the resource' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'with users allowed to the distance adjustments' do
    let!(:previous) { create(:resource, name: 'Ajustes de km', slug: 'distance_adjustments') }
    let!(:reader) { create(:user) }
    let!(:writer) { create(:user) }

    before do
      create(:access, user: reader, tenant: reader.tenant, resource: previous, reads: true)
      create(:access, user: writer, tenant: writer.tenant, resource: previous, reads: true, creates: true)
    end

    it 'gives them the same access to the route distances' do
      migration.up
      migration.up

      route_distances = Resource.find_by!(slug: 'route_distances')
      expect(Access.where(resource: route_distances).pluck(:user_id, :tenant_id, :reads, :creates))
        .to contain_exactly([reader.id, reader.tenant_id, true, false], [writer.id, writer.tenant_id, true, true])
    end

    it 'removes the resource and its accesses when rolling back' do
      migration.up

      expect { migration.down }.to change(Resource, :count).by(-1).and change(Access, :count).by(-2)
    end
  end
end
