require 'rails_helper'

RSpec.describe FreightBillingFilterForm do
  context 'without filters' do
    around { |example| travel_to(Date.new(2026, 10, 19)) { example.run } }

    it 'defaults to the current week from sunday to saturday grouped by customer group' do
      form = described_class.new

      expect(form).to be_valid
      expect(form).to have_attributes(dimension: 'customer_group', period: Date.new(2026, 10, 18)..Date.new(2026, 10, 24))
    end
  end

  describe '.preset_period on a sunday' do
    around { |example| travel_to(Date.new(2026, 10, 18)) { example.run } }

    it 'returns the week that ended the day before as the previous week' do
      expect(described_class.preset_period(:last_week)).to eq(Date.new(2026, 10, 11)..Date.new(2026, 10, 17))
    end
  end

  describe '.preset_period' do
    around { |example| travel_to(Date.new(2026, 10, 19)) { example.run } }

    it 'returns the current week from sunday to saturday' do
      expect(described_class.preset_period(:week)).to eq(Date.new(2026, 10, 18)..Date.new(2026, 10, 24))
    end

    it 'returns the previous week from sunday to saturday' do
      expect(described_class.preset_period(:last_week)).to eq(Date.new(2026, 10, 11)..Date.new(2026, 10, 17))
    end

    it 'returns the current month' do
      expect(described_class.preset_period(:month)).to eq(Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
    end

    it 'returns the whole previous month' do
      expect(described_class.preset_period(:last_month)).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    end

    it 'returns only the current day' do
      expect(described_class.preset_period(:today)).to eq(Date.new(2026, 10, 19)..Date.new(2026, 10, 19))
    end
  end

  context 'without filters on a sunday' do
    around { |example| travel_to(Date.new(2026, 10, 25)) { example.run } }

    it 'starts the week on that sunday' do
      expect(described_class.new.period).to eq(Date.new(2026, 10, 25)..Date.new(2026, 10, 31))
    end
  end

  context 'without filters on a saturday' do
    around { |example| travel_to(Date.new(2026, 10, 24)) { example.run } }

    it 'ends the week on that saturday' do
      expect(described_class.new.period).to eq(Date.new(2026, 10, 18)..Date.new(2026, 10, 24))
    end
  end

  context 'with a period and a dimension' do
    it 'casts the dates and keeps the dimension' do
      form = described_class.new(start_date: '2026-08-01', end_date: '2026-08-31', dimension: 'driver', customer_group_id: '7')

      expect(form).to be_valid
      expect(form).to have_attributes(dimension: 'driver', customer_group_id: 7, period: Date.new(2026, 8, 1)..Date.new(2026, 8, 31))
    end
  end

  context 'with only the start date' do
    it 'requires the end date' do
      form = described_class.new(start_date: '2026-08-01')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saídas até não pode ficar em branco'])
    end
  end

  context 'with the end date before the start date' do
    it 'is invalid' do
      form = described_class.new(start_date: '2026-08-31', end_date: '2026-08-01')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Saídas até não pode ser anterior à data inicial'])
    end
  end

  context 'with an unknown dimension' do
    it 'is invalid' do
      form = described_class.new(dimension: 'payer')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Agrupar por não está incluído na lista'])
    end
  end

  context 'with a truck group' do
    it 'keeps the group or the documents without group' do
      expect(described_class.new(truck_group_id: '12')).to be_valid
      expect(described_class.new(truck_group_id: 'none')).to have_attributes(valid?: true, truck_group_id: 'none')
    end
  end

  context 'with an unknown truck group' do
    it 'is invalid' do
      form = described_class.new(truck_group_id: 'rodotrem')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Tipo de conjunto não é válido'])
    end
  end

  describe '#filtered?' do
    let(:week) { described_class.preset_period(:week) }

    it 'is false with the defaults' do
      expect(described_class.new).not_to be_filtered
    end

    it 'is false when the defaults are sent explicitly' do
      form = described_class.new(start_date: week.first, end_date: week.last, dimension: 'customer_group')

      expect(form).not_to be_filtered
    end

    it 'is true with another dimension' do
      expect(described_class.new(dimension: 'driver')).to be_filtered
    end

    it 'is true with another period' do
      expect(described_class.new(start_date: week.first - 7, end_date: week.last - 7)).to be_filtered
    end

    it 'is true with a plate' do
      expect(described_class.new(plate: 'ABC1D23')).to be_filtered
    end
  end
end
