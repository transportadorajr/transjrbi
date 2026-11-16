require 'rails_helper'
require Rails.root.join('db/migrate/20261116204519_make_goals_resource_writable')

RSpec.describe MakeGoalsResourceWritable do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:resource) { create(:resource, name: 'Painel de metas', slug: 'goals', writable: false) }
  let!(:other_resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }

  it 'lets the goals panel be granted for editing' do
    migration.up

    expect(Resource.order(:id).pluck(:slug, :writable)).to eq([['goals', true], ['revenue_projection', false]])
  end

  it 'turns the goals panel back into read only and drops the editing granted on rollback' do
    access = create(:access, resource:, reads: true)
    migration.up
    access.update!(creates: true)
    migration.down

    expect(resource.reload).not_to be_writable
    expect(access.reload).to have_attributes(reads: true, creates: false)
  end
end
