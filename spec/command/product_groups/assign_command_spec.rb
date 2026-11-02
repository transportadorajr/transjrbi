require 'rails_helper'

RSpec.describe ProductGroups::AssignCommand do
  let(:tenant) { create(:tenant) }
  let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
  let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: ['BOBINA']) }
  let!(:wire) { create(:product_subgroup, tenant:, parent: steel, name: 'FIO MÁQUINA', product_names: ['FERRO (FIO MAQUINA/ VERGALHAO ROLO)']) }

  context 'with transport documents of the products of the subgroups' do
    let!(:coil_document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA') }
    let!(:wire_document) { create(:atua_transport_document, tenant:, product_name: "FERRO (FIO MAQUINA/ VERGALHAO ROLO) - '") }
    let!(:loose_document) { create(:atua_transport_document, tenant:, product_name: 'DIVERSOS') }
    let!(:blank_document) { create(:atua_transport_document, tenant:, product_name: nil) }
    let!(:stranger_document) { create(:atua_transport_document, product_name: 'BOBINA') }

    it 'links each document to the subgroup of its product ignoring accents, spaces and punctuation' do
      expect(described_class.call(tenant)).to eq(2)

      expect(coil_document.reload.product_group).to eq(coil)
      expect(wire_document.reload.product_group).to eq(wire)
      expect(loose_document.reload.product_group).to be_nil
      expect(blank_document.reload.product_group).to be_nil
      expect(stranger_document.reload.product_group).to be_nil
    end

    it 'can run again without changing any document' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'with a document linked to a product that left its subgroup' do
    let!(:document) { create(:atua_transport_document, tenant:, product_name: 'CHAPAS', product_group: coil) }

    it 'leaves the document without a group' do
      expect(described_class.call(tenant)).to eq(1)

      expect(document.reload.product_group).to be_nil
    end
  end

  context 'with an inactive subgroup or an inactive group' do
    let!(:coil_document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA', product_group: coil) }
    let!(:wire_document) { create(:atua_transport_document, tenant:, product_name: 'FERRO (FIO MAQUINA/ VERGALHAO ROLO)', product_group: wire) }
    let!(:food) { create(:product_group, tenant:, name: 'ALIMENTÍCIO', activated_at: nil) }
    let!(:flour) { create(:product_subgroup, tenant:, parent: food, product_names: ['FARINHA DE TRIGO']) }
    let!(:flour_document) { create(:atua_transport_document, tenant:, product_name: 'FARINHA DE TRIGO') }

    before { coil.update!(activated_at: nil) }

    it 'only classifies by the active subgroups of the active groups' do
      described_class.call(tenant)

      expect(coil_document.reload.product_group).to be_nil
      expect(wire_document.reload.product_group).to eq(wire)
      expect(flour_document.reload.product_group).to be_nil
    end
  end
end
