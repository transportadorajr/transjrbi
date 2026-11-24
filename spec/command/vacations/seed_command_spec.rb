require 'rails_helper'

RSpec.describe Vacations::SeedCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '.call' do
    context 'when the employees of the payroll report are registered' do
      before { Employees::SeedCommand.call(tenant) }

      it 'registers the vacations of the HR spreadsheet' do
        expect { described_class.call(tenant) }.to change(Vacation, :count).by(31)

        evandro = tenant.employees.find_by!(company_type: 'mme', registration: '00168')
        expect(evandro.vacations.sole).to have_attributes(
          tenant:, start_on: Date.new(2026, 2, 23), end_on: Date.new(2026, 3, 24), returns_on: Date.new(2026, 3, 25),
          acquisition_start_on: Date.new(2025, 2, 23), sold_days: 0, notes: nil
        )
        francisco = tenant.employees.find_by!(company_type: 'mm_espinola', registration: '00039')
        expect(francisco.vacations.sole).to have_attributes(
          start_on: Date.new(2027, 1, 5), end_on: Date.new(2027, 1, 19), sold_days: 5,
          notes: 'SOLICITOU 06/11 - 15 dias ferias + venda 5 dias'
        )
        jaqueline = tenant.employees.find_by!(company_type: 'mme', registration: '00176')
        expect(jaqueline.vacations.order(:start_on).pluck(:start_on, :end_on)).to eq(
          [[Date.new(2026, 6, 15), Date.new(2026, 6, 22)], [Date.new(2026, 9, 2), Date.new(2026, 9, 21)]],
        )
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00198').nickname).to eq('ROBINHO')
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00160').nickname).to eq('CABECA')
        expect(other_tenant.vacations.count).to eq(0)
      end

      it 'can run again without duplicating the vacations' do
        described_class.call(tenant)

        expect { described_class.call(tenant) }.not_to change(Vacation, :count)
      end
    end

    context 'when the employee has an admission date and a nickname' do
      let!(:evandro) do
        create(:employee, tenant:, company_type: 'mme', registration: '00168', nickname: 'KAIM', admitted_on: Date.new(2020, 7, 1))
      end
      let!(:robison) { create(:employee, tenant:, legal_id: nil, company_type: 'mme', registration: '00198', nickname: 'ROBSON') }

      it 'takes the acquisition period from the admission date and keeps the nickname' do
        expect { described_class.call(tenant) }.to change(Vacation, :count).by(3)

        expect(evandro.vacations.sole.acquisition_start_on).to eq(Date.new(2024, 7, 1))
        expect(robison.reload.nickname).to eq('ROBSON')
      end
    end

    context 'when the employee already has a vacation on those dates' do
      let!(:evandro) { create(:employee, tenant:, company_type: 'mme', registration: '00168', admitted_on: Date.new(2020, 7, 1)) }
      let!(:vacation) do
        create(:vacation, employee: evandro, start_on: Date.new(2026, 3, 1), end_on: Date.new(2026, 3, 20))
      end

      it 'keeps the registered vacation' do
        expect { described_class.call(tenant) }.not_to change(Vacation, :count)

        expect(evandro.vacations.sole).to eq(vacation)
      end
    end
  end
end
