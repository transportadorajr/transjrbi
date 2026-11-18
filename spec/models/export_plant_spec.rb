require 'rails_helper'

RSpec.describe ExportPlant do
  let!(:tenant) { create(:tenant) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }

  describe 'validations' do
    it 'requires a name' do
      plant = build(:export_plant, tenant:, customer_group: arcelor, name: '')

      expect(plant).not_to be_valid
      expect(plant.errors.full_messages).to eq(['Nome não pode ficar em branco'])
    end

    it 'does not repeat the name inside the same group' do
      create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora')

      expect(build(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora')).not_to be_valid
      expect(build(:export_plant, tenant:, name: 'Juiz de Fora')).to be_valid
    end
  end

  describe '#serves_city?' do
    let(:plant) { build(:export_plant, tenant:, customer_group: arcelor, cities: ['RESENDE', 'Barra Mansa']) }

    it 'matches the cities ignoring accents, spaces and case' do
      expect(plant.serves_city?('BARRA MANSA')).to be(true)
      expect(plant.serves_city?('resende')).to be(true)
      expect(plant.serves_city?('VOLTA REDONDA')).to be(false)
      expect(plant.serves_city?(nil)).to be(false)
    end
  end

  describe 'scopes' do
    let!(:juiz_de_fora) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }
    let!(:piracicaba) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Piracicaba', cities: ['PIRACICABA'], activated_at: nil) }
    let!(:ipatinga) { create(:export_plant, tenant:, name: 'Ipatinga') }

    it 'filters by name, group and status' do
      expect(described_class.by_name('juiz')).to contain_exactly(juiz_de_fora)
      expect(described_class.by_customer_group(arcelor.id)).to contain_exactly(juiz_de_fora, piracicaba)
      expect(described_class.by_status('active')).to contain_exactly(juiz_de_fora, ipatinga)
      expect(described_class.by_status('deactivated')).to contain_exactly(piracicaba)
    end
  end

  describe 'customer group' do
    it 'keeps a group that has a plant' do
      create(:export_plant, tenant:, customer_group: arcelor)

      expect(arcelor.destroy).to be(false)
      expect(arcelor.errors.full_messages).to eq(
        ['Não é possível excluir um grupo com clientes, regras de comissão, custos por tonelada, plantas ou atalhos de exportação vinculados. ' \
         'Desative o grupo para deixar de usá-lo.'],
      )
    end
  end

  describe '.enabled?' do
    it 'follows the export summary flag of the tenant', flipper: { export_summary: :tenant } do
      expect(described_class.enabled?(tenant)).to be(true)
      expect(described_class.enabled?(create(:tenant))).to be(false)
    end
  end
end
