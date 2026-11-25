require 'rails_helper'

RSpec.describe Employees::SeedAdmissionsCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '.call' do
    context 'when the employees of the payroll report are registered' do
      before do
        Employees::SeedCommand.call(tenant)
        Employees::SeedCommand.call(other_tenant)
      end

      it 'fills the admission date of every employee of the payroll report' do
        described_class.call(tenant)

        expect(tenant.employees.where.not(admitted_on: nil).group(:company_type).count)
          .to eq('transjr' => 1, 'mme' => 40, 'mm_espinola' => 43)
        expect(tenant.employees.find_by!(company_type: 'transjr', registration: '00073').admitted_on)
          .to eq(Date.new(2025, 6, 12))
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00010').admitted_on)
          .to eq(Date.new(2013, 6, 1))
        expect(tenant.employees.find_by!(company_type: 'mm_espinola', registration: '00010').admitted_on)
          .to eq(Date.new(2020, 11, 12))
        expect(tenant.employees.where(admitted_on: nil).pluck(:company_type, :registration))
          .to contain_exactly(%w[mme 00241], %w[mme 00244], %w[mm_espinola 00101])
        expect(other_tenant.employees.where.not(admitted_on: nil).count).to eq(0)
      end

      it 'can run again without changing the records' do
        described_class.call(tenant)

        expect { described_class.call(tenant) }.not_to(change { tenant.employees.order(:id).pluck(:admitted_on, :updated_at) })
      end

      it 'realigns the vacations registered without an admission date to the acquisition period' do
        Vacations::SeedCommand.call(tenant)
        evandro = tenant.employees.find_by!(company_type: 'mme', registration: '00168')
        expect(evandro.vacations.sole.acquisition_start_on).to eq(Date.new(2025, 2, 23))

        described_class.call(tenant)

        expect(evandro.reload.admitted_on).to eq(Date.new(2023, 12, 2))
        expect(evandro.vacations.sole.acquisition_start_on).to eq(Date.new(2024, 12, 2))
      end
    end

    context 'when the employee already has an admission date' do
      let!(:sidney) do
        create(:employee, tenant:, name: 'SIDNEY ZEN', legal_id: nil, company_type: 'mme', registration: '00205',
                          admitted_on: Date.new(2025, 8, 4))
      end
      let!(:vacation) do
        create(:vacation, employee: sidney, acquisition_start_on: Date.new(2025, 8, 4), start_on: Date.new(2026, 9, 1))
      end

      it 'keeps the registered admission date and vacations' do
        described_class.call(tenant)

        expect(sidney.reload.admitted_on).to eq(Date.new(2025, 8, 4))
        expect(vacation.reload.acquisition_start_on).to eq(Date.new(2025, 8, 4))
      end
    end
  end
end
