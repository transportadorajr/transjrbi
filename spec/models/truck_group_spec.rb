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

    it 'accepts a group of the remaining axles without axle counts' do
      expect(build(:truck_group, :others, tenant:)).to be_valid
    end

    it 'accepts a group of plates without axle counts' do
      expect(build(:truck_group, :utinga, tenant:)).to be_valid
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

  describe '.for_document' do
    let(:rodotrem) { build(:truck_group, axles: [9]) }
    let(:quarto_eixo) { build(:truck_group, name: 'Quarto eixo', axles: [7, 8]) }

    it 'finds the group that contains the axle count' do
      expect(described_class.for_document([rodotrem, quarto_eixo], plate: 'RVR2C34', axles: 8)).to eq(quarto_eixo)
      expect(described_class.for_document([rodotrem, quarto_eixo], plate: 'RVR2C34', axles: 6)).to be_nil
    end

    it 'falls back to the group of the remaining axles' do
      others = build(:truck_group, :others)

      expect(described_class.for_document([others, rodotrem, quarto_eixo], plate: 'RVR2C34', axles: 9)).to eq(rodotrem)
      expect(described_class.for_document([others, rodotrem, quarto_eixo], plate: 'RVR2C34', axles: 4)).to eq(others)
      expect(described_class.for_document([others, rodotrem, quarto_eixo], plate: nil, axles: nil)).to eq(others)
    end

    it 'prefers the group of the plate over the group of the axle count' do
      utinga = build(:truck_group, :utinga)

      expect(described_class.for_document([rodotrem, utinga], plate: 'BAV5A04', axles: 9)).to eq(utinga)
      expect(described_class.for_document([rodotrem, utinga], plate: 'RVR2C34', axles: 9)).to eq(rodotrem)
    end
  end

  describe 'fuel rates' do
    let(:truck_group) { create(:truck_group, tenant:, fuel_percentage: BigDecimal('35')) }
    let(:current_month) { Date.current.beginning_of_month }

    def rates
      truck_group.fuel_rates.reload.order(:valid_month).pluck(:valid_month, :percentage)
    end

    it 'records the initial percentage when the group is created' do
      expect(rates).to eq([[current_month, BigDecimal('35')]])
    end

    it 'does not record a rate when the percentage of the month does not change' do
      expect { truck_group.change_fuel_percentage(BigDecimal('35'), current_month) }.not_to(change { rates })
    end

    it 'keeps the previous months when the only rate of the month changes' do
      truck_group.change_fuel_percentage(BigDecimal('40'), current_month)

      expect(rates).to eq([[current_month.prev_month, BigDecimal('35')], [current_month, BigDecimal('40')]])
      expect(truck_group.fuel_percentage).to eq(BigDecimal('40'))
      expect(truck_group.fuel_percentage_for(current_month.months_ago(6))).to eq(BigDecimal('35'))
    end

    it 'keeps the months before a percentage registered earlier than the first rate' do
      truck_group.change_fuel_percentage(BigDecimal('30'), current_month.months_ago(2))

      expect(truck_group.fuel_percentage_for(current_month.months_ago(3))).to eq(BigDecimal('35'))
      expect(truck_group.fuel_percentage_for(current_month.months_ago(2))).to eq(BigDecimal('30'))
      expect(truck_group.fuel_percentage_for(current_month.prev_month)).to eq(BigDecimal('30'))
      expect(truck_group.fuel_percentage_for(current_month)).to eq(BigDecimal('35'))
    end

    it 'keeps the current percentage when correcting a past month' do
      truck_group.change_fuel_percentage(BigDecimal('40'), current_month)
      truck_group.change_fuel_percentage(BigDecimal('30'), current_month.prev_month)

      expect(truck_group.fuel_percentage).to eq(BigDecimal('40'))
      expect(truck_group.fuel_percentage_for(current_month.prev_month)).to eq(BigDecimal('30'))
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
