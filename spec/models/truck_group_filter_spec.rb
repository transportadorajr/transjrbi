require 'rails_helper'

RSpec.describe TruckGroupFilter do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:rodotrem_group) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }
  let!(:utinga_group) { create(:truck_group, :utinga, tenant:) }
  let!(:stranger_group) { create(:truck_group, tenant: other_tenant, name: 'Grupo de outra', axles: [3]) }
  let!(:rodotrem) { create(:atua_transport_document, tenant:, plate: 'RDT9A99', axles: 9) }
  let!(:utinga) { create(:atua_transport_document, tenant:, plate: 'BAV5A04', axles: 9) }
  let!(:truck) { create(:atua_transport_document, tenant:, plate: 'TRK3E33', axles: 3) }
  let(:truck_groups) { tenant.truck_groups.order(:name) }
  let(:documents) { tenant.atua_transport_documents }

  def filter(value)
    described_class.new(truck_groups, value)
  end

  describe '.except_value' do
    it 'prefixes the id of the group' do
      expect(described_class.except_value(utinga_group)).to eq("except-#{utinga_group.id}")
    end
  end

  describe '#apply' do
    it 'keeps every document without a group' do
      expect(Atua::TransportDocument.count).to eq(3)
      expect(filter(nil).apply(documents)).to contain_exactly(rodotrem, utinga, truck)
      expect(filter('').apply(documents)).to contain_exactly(rodotrem, utinga, truck)
    end

    it 'keeps only the documents of the group' do
      expect(filter(utinga_group.id).apply(documents)).to eq([utinga])
      expect(filter(rodotrem_group.id.to_s).apply(documents)).to eq([rodotrem])
    end

    it 'keeps every document except the ones of the group' do
      expect(filter("except-#{utinga_group.id}").apply(documents)).to contain_exactly(rodotrem, truck)
      expect(filter("except-#{rodotrem_group.id}").apply(documents)).to contain_exactly(utinga, truck)
    end

    it 'finds nothing for a group of another tenant' do
      expect(filter(stranger_group.id).apply(documents)).to be_empty
      expect(filter("except-#{stranger_group.id}").apply(documents)).to be_empty
    end
  end

  describe '#name' do
    it 'names the group or every group except it' do
      expect(filter(utinga_group.id).name).to eq('Utinga')
      expect(filter("except-#{utinga_group.id}").name).to eq('Todos, menos Utinga')
      expect(filter(stranger_group.id).name).to be_nil
    end
  end
end
