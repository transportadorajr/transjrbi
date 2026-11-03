require 'rails_helper'

RSpec.describe ProductGroups::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'with transport documents of known products' do
    let!(:coil_document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA') }
    let!(:wire_document) { create(:atua_transport_document, tenant:, product_name: "FERRO (FIO MAQUINA/ VERGALHAO ROLO) - '") }
    let!(:flour_document) { create(:atua_transport_document, tenant:, product_name: 'FARINHA DE TRIGO') }
    let!(:loose_document) { create(:atua_transport_document, tenant:, product_name: 'DIVERSOS') }
    let!(:panel_document) { create(:atua_transport_document, tenant:, product_name: 'GER FOTOVOLTAICO DE POT') }

    it 'creates only the groups and subgroups of the products of the tenant and classifies the documents' do
      expect { described_class.call(tenant) }.to change(ProductGroup, :count).by(7)

      expect(tenant.product_groups.groups.order(:id).map { |group| [group.name, group.subgroups.order(:id).pluck(:name, :product_names)] }).to eq(
        [
          ['SIDERÚRGICO', [['BOBINA', ['BOBINA']], ['FIO MÁQUINA', ["FERRO (FIO MAQUINA/ VERGALHAO ROLO) - '"]]]],
          ['ALIMENTÍCIO', [['FARINHAS', ['FARINHA DE TRIGO']]]],
          ['DIVERSOS', [['DIVERSOS', ['DIVERSOS', 'GER FOTOVOLTAICO DE POT']]]],
        ],
      )
      expect(tenant.product_groups.activated.count).to eq(7)
      expect(coil_document.reload.product_group.name).to eq('BOBINA')
      expect(wire_document.reload.product_group.name).to eq('FIO MÁQUINA')
      expect(flour_document.reload.product_group.name).to eq('FARINHAS')
      expect(loose_document.reload.product_group.name).to eq('DIVERSOS')
      expect(panel_document.reload.product_group.name).to eq('DIVERSOS')
      expect(Atua::TransportDocument.where(product_group_id: nil)).to be_empty
    end

    it 'does not touch a tenant that already has product groups' do
      described_class.call(tenant)
      tenant.product_groups.find_by!(name: 'BOBINA').update!(product_names: [])

      expect { expect(described_class.call(tenant)).to eq([]) }.not_to(change { ProductGroup.order(:id).pluck(:id, :name, :product_names) })
    end
  end

  context 'with beverages and empty bottles' do
    let!(:beer_document) { create(:atua_transport_document, tenant:, product_name: 'CERVEJA') }
    let!(:bottle_document) { create(:atua_transport_document, tenant:, product_name: 'VASILHAME') }

    it 'classifies the empty bottles in the BEBIDAS subgroup' do
      described_class.call(tenant)

      expect(tenant.product_groups.nested.pluck(:name, :product_names)).to eq([['BEBIDAS', %w[CERVEJA VASILHAME]]])
      expect([beer_document, bottle_document].map { |document| document.reload.product_group.name }).to eq(%w[BEBIDAS BEBIDAS])
    end
  end

  context 'when every product belongs to a known subgroup' do
    let!(:document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA') }

    it 'does not create the DIVERSOS group' do
      described_class.call(tenant)

      expect(tenant.product_groups.groups.pluck(:name)).to eq(['SIDERÚRGICO'])
    end
  end

  context 'without transport documents' do
    it 'creates no group' do
      expect { described_class.call(tenant) }.not_to change(ProductGroup, :count)
    end
  end
end
