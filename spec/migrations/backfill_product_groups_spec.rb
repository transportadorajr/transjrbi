require 'rails_helper'
require Rails.root.join('db/migrate/20261102185520_backfill_product_groups')

RSpec.describe BackfillProductGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with transport documents of known products' do
    let!(:tenant) { create(:tenant) }
    let!(:document) { create(:atua_transport_document, tenant:, product_name: 'VERGALHAO DE FERRO') }

    it 'creates the product groups of the tenant and classifies its documents' do
      expect { migration.up }.to change(ProductGroup, :count).by(2)

      expect(document.reload.product_group).to have_attributes(name: 'VERGALHÃO', parent: have_attributes(name: 'SIDERÚRGICO'))
    end

    it 'can run again without changing the groups' do
      migration.up

      expect { migration.up }.not_to(change { ProductGroup.order(:id).pluck(:id, :name, :updated_at) })
    end
  end
end
