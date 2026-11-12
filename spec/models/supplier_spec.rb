require 'rails_helper'

RSpec.describe Supplier do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }

    it 'requires a name unique by tenant' do
      expect(build(:supplier, tenant:, name: 'RETÍFICA IPATINGA')).not_to be_valid
      expect(build(:supplier, tenant:, name: '')).not_to be_valid
      expect(build(:supplier, name: 'RETÍFICA IPATINGA')).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }
    let!(:inactive_supplier) { create(:supplier, tenant:, name: 'BORRACHARIA CENTRAL', active: false) }

    it 'filters by name and activity' do
      expect(described_class.by_name('ipatinga')).to eq([active_supplier])
      expect(described_class.active).to eq([active_supplier])
    end
  end
end
