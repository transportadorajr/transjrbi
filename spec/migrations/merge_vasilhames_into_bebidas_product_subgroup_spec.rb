require 'rails_helper'
require Rails.root.join('db/migrate/20261103164538_merge_vasilhames_into_bebidas_product_subgroup')

RSpec.describe MergeVasilhamesIntoBebidasProductSubgroup do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with beverage documents classified in separate subgroups' do
    let!(:tenant) { create(:tenant) }
    let!(:beer_document) { create(:atua_transport_document, tenant:, product_name: 'CERVEJA') }
    let!(:bottle_document) { create(:atua_transport_document, tenant:, product_name: 'VASILHAME') }

    before do
      group = create(:product_group, tenant:, name: 'BEBIDAS')
      create(:product_subgroup, tenant:, parent: group, name: 'BEBIDAS', product_names: %w[CERVEJA])
      create(:product_subgroup, tenant:, parent: group, name: 'VASILHAMES', product_names: %w[VASILHAME])
      ProductGroups::AssignCommand.call(tenant)
    end

    it 'keeps only the BEBIDAS subgroup with every beverage document' do
      migration.up

      expect(tenant.product_groups.nested.pluck(:name)).to eq(['BEBIDAS'])
      expect([beer_document, bottle_document].map { |document| document.reload.product_group.name }).to eq(%w[BEBIDAS BEBIDAS])
    end
  end
end
