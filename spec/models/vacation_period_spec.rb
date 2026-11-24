require 'rails_helper'

RSpec.describe VacationPeriod do
  let(:employee) { create(:employee, admitted_on: Date.new(2024, 3, 10)) }

  describe '.for_employee' do
    it 'starts a period on every anniversary of the admission up to the given day' do
      periods = described_class.for_employee(employee, until_on: Date.new(2026, 3, 10))

      expect(periods.map { |period| [period.start_on, period.end_on, period.deadline_on] }).to eq(
        [
          [Date.new(2024, 3, 10), Date.new(2025, 3, 9), Date.new(2026, 3, 9)],
          [Date.new(2025, 3, 10), Date.new(2026, 3, 9), Date.new(2027, 3, 9)],
          [Date.new(2026, 3, 10), Date.new(2027, 3, 9), Date.new(2028, 3, 9)],
        ],
      )
    end

    it 'has no period without an admission date' do
      employee.update!(admitted_on: nil)

      expect(described_class.for_employee(employee)).to eq([])
    end

    it 'keeps the anniversary of an admission on February 29th' do
      employee.update!(admitted_on: Date.new(2024, 2, 29))

      periods = described_class.for_employee(employee, until_on: Date.new(2028, 3, 1))

      expect(periods.map(&:start_on)).to eq([Date.new(2024, 2, 29), Date.new(2025, 2, 28), Date.new(2026, 2, 28), Date.new(2027, 2, 28),
                                             Date.new(2028, 2, 29)])
      expect(periods.second.end_on).to eq(Date.new(2026, 2, 27))
    end
  end

  describe '#balance and #status' do
    let(:period) { described_class.find(employee, Date.new(2024, 3, 10)) }

    it 'subtracts the days taken and sold from the 30 days' do
      create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 14), sold_days: 10)

      expect(period.enjoyed_days).to eq(14)
      expect(period.sold_days).to eq(10)
      expect(period.balance).to eq(6)
    end

    it 'follows the period from the acquisition to the deadline' do
      expect(period.status(Date.new(2025, 1, 1))).to eq(:acquiring)
      expect(period.status(Date.new(2025, 6, 1))).to eq(:open)
      expect(period.status(Date.new(2026, 1, 8))).to eq(:due_soon)
      expect(period.status(Date.new(2026, 3, 10))).to eq(:overdue)
    end

    it 'is taken when there is no balance left' do
      create(:vacation, employee:, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30))

      expect(period.status(Date.new(2026, 3, 10))).to eq(:taken)
    end
  end
end
