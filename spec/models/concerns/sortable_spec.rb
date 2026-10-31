require 'rails_helper'

RSpec.describe Sortable do
  let!(:tenant) { create(:tenant) }
  let!(:alvaro) { create(:macro_region, tenant:, name: 'Álvaro') }
  let!(:beta) { create(:macro_region, tenant:, name: 'beta') }
  let!(:carlos) { create(:macro_region, tenant:, name: 'Carlos') }

  describe '.sortable_column?' do
    it 'accepts only the declared columns' do
      expect(MacroRegion.sortable_column?('name')).to be(true)
      expect(MacroRegion.sortable_column?(:name)).to be(true)
      expect(MacroRegion.sortable_column?('state')).to be(false)
      expect(MacroRegion.sortable_column?(nil)).to be(false)
      expect(MacroRegion.sortable_column?({ 'name' => '1' })).to be(false)
    end
  end

  describe '.sorted_by' do
    it 'compares the text ignoring accents and letter case' do
      expect(MacroRegion.sorted_by('name', 'asc').to_a).to eq([alvaro, beta, carlos])
    end

    it 'reverses the order for the descending direction' do
      expect(MacroRegion.sorted_by('name', 'desc').to_a).to eq([carlos, beta, alvaro])
    end

    it 'falls back to the ascending direction for an unknown direction' do
      expect(MacroRegion.sorted_by('name', 'sideways').to_a).to eq([alvaro, beta, carlos])
    end

    it 'keeps the current scope of the relation' do
      expect(MacroRegion.where(id: [beta.id, carlos.id]).sorted_by('name', 'desc').to_a).to eq([carlos, beta])
    end
  end

  context 'with blank values' do
    let!(:named) { create(:atua_customer, tenant:, name: 'ZULU') }
    let!(:blank) { create(:atua_customer, tenant:, name: '') }
    let!(:missing) { create(:atua_customer, tenant:, name: nil) }

    it 'lists them last in both directions' do
      expect(Atua::Customer.sorted_by('name', 'asc').first).to eq(named)
      expect(Atua::Customer.sorted_by('name', 'desc').first).to eq(named)
      expect(Atua::Customer.sorted_by('name', 'desc').order(:id).last(2)).to contain_exactly(blank, missing)
    end
  end
end
