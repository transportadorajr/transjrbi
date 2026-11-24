require 'rails_helper'

RSpec.describe Dashboard::VacationBalances do
  subject(:balances) { described_class.new(today: Date.new(2026, 11, 24)) }

  let(:tenant) { create(:tenant) }
  let!(:overdue) { create(:employee, tenant:, name: 'ANA', legal_id: '00000000051', admitted_on: Date.new(2024, 10, 1)) }
  let!(:due_soon) { create(:employee, tenant:, name: 'BRUNO', legal_id: '00000000052', admitted_on: Date.new(2025, 1, 10)) }
  let!(:taken) { create(:employee, tenant:, name: 'CARLOS', legal_id: '00000000053', admitted_on: Date.new(2025, 1, 10)) }
  let!(:recent) { create(:employee, tenant:, name: 'DIEGO', legal_id: '00000000054', admitted_on: Date.new(2026, 5, 1)) }

  before do
    create(:employee, tenant:, name: 'EDSON', legal_id: '00000000055', admitted_on: Date.new(2024, 10, 1), activated: false)
    create(:employee, tenant:, name: 'FABIO', legal_id: '00000000056')
    create(:vacation, employee: overdue, acquisition_start_on: Date.new(2024, 10, 1), start_on: Date.new(2025, 11, 1),
                      end_on: Date.new(2025, 11, 20))
    create(:vacation, employee: taken, acquisition_start_on: Date.new(2025, 1, 10), start_on: Date.new(2026, 2, 1),
                      end_on: Date.new(2026, 3, 2))
  end

  def periods
    balances.periods(tenant.employees)
  end

  it 'lists the acquired periods with balance of the active employees by deadline' do
    expect(periods.map { |period| [period.employee.name, period.start_on, period.balance, period.status(Date.new(2026, 11, 24))] }).to eq(
      [
        ['ANA', Date.new(2024, 10, 1), 10, :overdue],
        ['BRUNO', Date.new(2025, 1, 10), 30, :due_soon],
        ['ANA', Date.new(2025, 10, 1), 30, :open],
      ],
    )
  end

  it 'filters and counts the periods by status' do
    expect(balances.with_status(periods, 'due_soon').map { |period| period.employee.name }).to eq(['BRUNO'])
    expect(balances.with_status(periods, 'anything').size).to eq(3)
    expect(balances.counts(periods)).to eq(overdue: 1, due_soon: 1, open: 1)
  end
end
