require 'rails_helper'
require Rails.root.join('db/migrate/20261014173820_add_expenses_resource')

RSpec.describe AddExpensesResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the expenses resource' do
    it 'creates the read-only resource of expenses' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['expenses', 'Despesas', false]])
    end

    it 'can run again without duplicating the resource' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'with a resource already registered under the same slug' do
    let!(:resource) { create(:resource, name: 'Gastos', slug: 'expenses', writable: true) }

    it 'keeps the existing resource untouched' do
      expect { migration.up }.not_to change(Resource, :count)

      expect(resource.reload.name).to eq('Gastos')
      expect(resource.writable).to be(true)
    end
  end

  context 'when rolling back' do
    let!(:other_resource) { create(:resource, slug: 'users') }

    before { migration.up }

    it 'removes only the expenses resource' do
      expect { migration.down }.to change(Resource, :count).by(-1)

      expect(Resource.pluck(:slug)).to eq(['users'])
    end
  end

  context 'when rolling back with permissions on the expenses resource' do
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'expenses'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
