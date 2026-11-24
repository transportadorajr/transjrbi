require 'rails_helper'

RSpec.describe LifeInsurances::SeedCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '.call' do
    context 'when the employees of the payroll report are registered' do
      before { Employees::SeedCommand.call(tenant) }

      it 'registers the policies and the life insurances of the HR spreadsheet' do
        expect { described_class.call(tenant) }.to change(LifeInsurancePolicy, :count).by(2).and change(LifeInsurance, :count).by(46)

        expect(tenant.life_insurance_policies.order(:company_type).map { |policy| policy.slice(:company_type, :capital_cents).symbolize_keys })
          .to eq([{ company_type: 'mme', capital_cents: 11_500_000 }, { company_type: 'mm_espinola', capital_cents: 11_000_000 }])
        expect(tenant.life_insurance_policies.find_by!(company_type: 'mme')).to have_attributes(
          premium_rate_per_mille: BigDecimal('0.3185'), spouse_percentage: 50, children_percentage: 10, funeral_assistance_cents: 600_000,
        )
        expect(tenant.life_insurances.joins(:employee).group('employees.company_type').count).to eq('mme' => 24, 'mm_espinola' => 22)
        expect(tenant.life_insurances.sum { |life_insurance| life_insurance.premium.cents }).to eq(165_000)
        expect(tenant.life_insurances.where.not(capital_cents: nil).count).to eq(0)
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00160').life_insurances.sole)
          .to have_attributes(capital: Money.from_cents(11_500_000), included_on: nil, excluded_on: nil)
        expect(other_tenant.life_insurances.count).to eq(0)
      end

      it 'can run again without duplicating the policies and the life insurances' do
        described_class.call(tenant)

        expect { described_class.call(tenant) }.not_to change(LifeInsurancePolicy, :count)
        expect { described_class.call(tenant) }.not_to change(LifeInsurance, :count)
      end

      it 'keeps a policy and an exclusion already registered by the HR' do
        policy = create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 12_000_000)
        employee = tenant.employees.find_by!(company_type: 'mme', registration: '00160')
        excluded = create(:life_insurance, employee:, life_insurance_policy: policy, excluded_on: Date.new(2026, 11, 1))

        described_class.call(tenant)

        expect(policy.reload.capital_cents).to eq(12_000_000)
        expect(employee.life_insurances).to eq([excluded])
      end
    end

    it 'registers only the policies when the employees are not registered' do
      expect { described_class.call(tenant) }.to change(LifeInsurancePolicy, :count).by(2)
      expect(LifeInsurance.count).to eq(0)
    end
  end
end
