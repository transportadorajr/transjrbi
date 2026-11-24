require 'rails_helper'

RSpec.describe Vacation do
  describe 'validations' do
    it 'requires the dates and a non negative number of sold days' do
      vacation = described_class.new(sold_days: -1)

      expect(vacation).not_to be_valid
      expect(vacation.errors.attribute_names).to include(:acquisition_start_on, :start_on, :end_on, :sold_days)
    end
  end

  describe '#days_count and #returns_on' do
    it 'counts the days off including both ends and returns on the next day' do
      vacation = build(:vacation, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 20))

      expect(vacation.days_count).to eq(20)
      expect(vacation.returns_on).to eq(Date.new(2025, 4, 21))
    end
  end

  describe '#acquisition_end_on' do
    it 'ends the acquisition period one year after its start' do
      vacation = build(:vacation, acquisition_start_on: Date.new(2024, 3, 10))

      expect(vacation.acquisition_end_on).to eq(Date.new(2025, 3, 9))
    end

    it 'ends the acquisition period when the employee has no admission date' do
      vacation = build(:vacation, employee: build(:employee, admitted_on: nil), acquisition_start_on: Date.new(2025, 2, 23))

      expect(vacation.acquisition_end_on).to eq(Date.new(2026, 2, 22))
    end
  end

  describe 'scopes' do
    let(:tenant) { create(:tenant) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', company_type: 'transjr', admitted_on: Date.new(2024, 3, 10)) }
    let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme', admitted_on: Date.new(2024, 3, 10)) }
    let!(:april) { create(:vacation, employee: jose, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 30)) }
    let!(:may) { create(:vacation, employee: ana, start_on: Date.new(2025, 4, 25), end_on: Date.new(2025, 5, 24)) }

    it 'filters the vacations that touch a month' do
      expect(described_class.by_month('2025-04')).to contain_exactly(april, may)
      expect(described_class.by_month('2025-05')).to contain_exactly(may)
      expect(described_class.by_month('2025-06')).to be_empty
    end

    it 'filters by the name and the company of the employee' do
      expect(described_class.by_name('jose')).to contain_exactly(april)
      expect(described_class.by_company_type('mme')).to contain_exactly(may)
    end
  end
end
