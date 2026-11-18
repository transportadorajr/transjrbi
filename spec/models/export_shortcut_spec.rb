require 'rails_helper'

RSpec.describe ExportShortcut do
  let!(:tenant) { create(:tenant) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
  let!(:juiz_de_fora) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }

  def fact(customer_group_id: arcelor.id, plant_key: "plant-#{juiz_de_fora.id}", country: 'paraguay')
    Dashboard::ExportFacts::Fact.new(document_id: 1, number: '74001', trip_on: Date.new(2026, 11, 2), manifest_code: 1, manifest_number: '1',
                                     plate: 'RHJ4E07', customer_group_id:, origin_city: 'JUIZ DE FORA', origin_state: 'MG',
                                     recipient_name: 'ACEROS ASUNCION SA', country:, tons: BigDecimal('30'), plant_key:, plant_label: 'Juiz de Fora')
  end

  describe 'validations' do
    it 'requires a name unique in the tenant' do
      create(:export_shortcut, tenant:, name: 'Arcelor Paraguai')

      expect(build(:export_shortcut, tenant:, name: '')).not_to be_valid
      expect(build(:export_shortcut, tenant:, name: 'Arcelor Paraguai')).not_to be_valid
      expect(build(:export_shortcut, name: 'Arcelor Paraguai')).to be_valid
    end
  end

  describe '#matches?' do
    it 'matches every loading when nothing is chosen' do
      expect(build(:export_shortcut, tenant:).matches?(fact(customer_group_id: nil, plant_key: 'city-CUBATAO-SP', country: 'unknown'))).to be(true)
    end

    it 'matches only the chosen group, plants and countries' do
      shortcut = build(:export_shortcut, tenant:, customer_group: arcelor, export_plant_ids: [juiz_de_fora.id], countries: %w[paraguay argentina])

      expect(shortcut.matches?(fact)).to be(true)
      expect(shortcut.matches?(fact(country: 'argentina'))).to be(true)
      expect(shortcut.matches?(fact(country: 'unknown'))).to be(false)
      expect(shortcut.matches?(fact(plant_key: 'city-JUIZDEFORA-MG'))).to be(false)
      expect(shortcut.matches?(fact(customer_group_id: nil))).to be(false)
    end
  end

  describe '#export_plants and .ordered' do
    let!(:piracicaba) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Piracicaba', cities: ['PIRACICABA']) }

    it 'loads the chosen plants of the tenant and sorts the shortcuts by position and name' do
      second = create(:export_shortcut, tenant:, name: 'B', position: 1, export_plant_ids: [piracicaba.id, juiz_de_fora.id, create(:export_plant).id])
      first = create(:export_shortcut, tenant:, name: 'Z', position: 0)
      third = create(:export_shortcut, tenant:, name: 'C', position: 1)

      expect(second.export_plants).to eq([juiz_de_fora, piracicaba])
      expect(tenant.export_shortcuts.ordered).to eq([first, second, third])
    end
  end
end
