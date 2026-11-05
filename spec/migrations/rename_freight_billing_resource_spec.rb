require 'rails_helper'
require Rails.root.join('db/migrate/20261105123641_rename_freight_billing_resource')

RSpec.describe RenameFreightBillingResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }
  let!(:other_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }

  it 'renames the freight billing resource to Faturamento' do
    migration.up

    expect(Resource.order(:id).pluck(:slug, :name)).to eq([%w[freight_billing Faturamento], %w[manifests Manifestos]])
  end

  it 'restores the previous name on rollback' do
    migration.up
    migration.down

    expect(resource.reload.name).to eq('Faturamento de fretes')
  end
end
