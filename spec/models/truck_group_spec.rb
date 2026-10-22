require 'rails_helper'

RSpec.describe TruckGroup do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:rodotrem) { create(:truck_group, tenant:) }

    it 'requires a name unique by tenant, the axle counts and a fuel percentage from 0 to 100' do
      truck_group = build(:truck_group, tenant:, name: 'Rodotrem', axles: [], fuel_percentage: 101)

      expect(truck_group).not_to be_valid
      expect(truck_group.errors.full_messages).to contain_exactly(
        'Nome já está em uso', 'Quantidades de eixos não pode ficar em branco', 'Combustível sobre o frete deve ser menor ou igual a 100'
      )
    end

    it 'accepts the same name in another tenant' do
      expect(build(:truck_group, name: 'Rodotrem')).to be_valid
    end
  end

  describe 'scopes' do
    let!(:rodotrem) { create(:truck_group, tenant:) }
    let!(:ls) { create(:truck_group, :ls, tenant:, activated_at: nil) }

    it 'filters by name and by status' do
      expect(described_class.count).to eq(2)
      expect(described_class.by_name('rodo')).to eq([rodotrem])
      expect(described_class.by_status('active')).to eq([rodotrem])
      expect(described_class.by_status('deactivated')).to eq([ls])
    end
  end

  describe '.statuses' do
    it 'maps the translated statuses to the filter keys' do
      expect(described_class.statuses).to eq('Ativo' => :active, 'Inativo' => :deactivated)
    end
  end

  describe '.for_axles' do
    let(:rodotrem) { build(:truck_group, axles: [9]) }
    let(:quarto_eixo) { build(:truck_group, name: 'Quarto eixo', axles: [7, 8]) }

    it 'finds the group that contains the axle count' do
      expect(described_class.for_axles([rodotrem, quarto_eixo], 8)).to eq(quarto_eixo)
      expect(described_class.for_axles([rodotrem, quarto_eixo], 6)).to be_nil
    end
  end

  describe '#fuel_cents' do
    it 'applies the fuel percentage to the freight rounding half up' do
      truck_group = build(:truck_group, fuel_percentage: BigDecimal('32.5'))

      expect(truck_group.fuel_cents(1_000_000)).to eq(325_000)
      expect(truck_group.fuel_cents(101)).to eq(33)
      expect(truck_group.fuel_cents(nil)).to eq(0)
    end
  end
end
