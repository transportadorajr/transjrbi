require 'rails_helper'

RSpec.describe MaintenancePart do
  let(:tenant) { create(:tenant) }
  let!(:lining) { create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO') }
  let!(:oil) { create(:maintenance_part, tenant:, description: 'ÓLEO 15W40', active: false) }

  describe '.by_term' do
    it 'finds the parts by code or description' do
      expect(tenant.maintenance_parts.by_term('lf-1')).to contain_exactly(lining)
      expect(tenant.maintenance_parts.by_term('15w')).to contain_exactly(oil)
    end
  end

  describe '.by_status' do
    it 'filters the active or inactive parts and ignores an unknown status' do
      expect(tenant.maintenance_parts.by_status('active')).to contain_exactly(lining)
      expect(tenant.maintenance_parts.by_status('inactive')).to contain_exactly(oil)
      expect(tenant.maintenance_parts.by_status('other')).to contain_exactly(lining, oil)
    end
  end

  describe '#label' do
    it 'joins the code and the description' do
      expect(lining.label).to eq('LF-123 - LONA DE FREIO')
      expect(oil.label).to eq('ÓLEO 15W40')
    end
  end

  describe '#destroy' do
    it 'keeps a part used in a work order' do
      create(:maintenance_order_part, maintenance_order: create(:maintenance_order, tenant:), maintenance_part: lining)

      expect(lining.destroy).to be(false)
      expect(described_class.exists?(lining.id)).to be(true)
    end
  end
end
