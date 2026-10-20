require 'rails_helper'

RSpec.describe FreightBillingFilterForm do
  context 'without filters' do
    around { |example| travel_to(Date.new(2026, 10, 19)) { example.run } }

    it 'defaults to the current month grouped by vehicle' do
      form = described_class.new

      expect(form).to be_valid
      expect(form).to have_attributes(dimension: 'vehicle', period: Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
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
end
