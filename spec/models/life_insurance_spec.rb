require 'rails_helper'

RSpec.describe LifeInsurance do
  describe 'validations' do
    it 'accepts a life insurance without capital and dates' do
      expect(build(:life_insurance, capital_cents: nil, included_on: nil, excluded_on: nil)).to be_valid
    end

    it 'requires a positive capital' do
      life_insurance = build(:life_insurance, capital_cents: 0)

      expect(life_insurance).not_to be_valid
      expect(life_insurance.errors.attribute_names).to eq([:capital_cents])
    end

    it 'rejects an exclusion before the inclusion' do
      life_insurance = build(:life_insurance, included_on: Date.new(2026, 5, 10), excluded_on: Date.new(2026, 5, 9))

      expect(life_insurance).not_to be_valid
      expect(life_insurance.errors.full_messages).to eq(['Exclusão não pode ser anterior à inclusão'])
    end

    it 'rejects a policy of another company' do
      employee = create(:employee, company_type: 'mme')
      policy = create(:life_insurance_policy, tenant: employee.tenant, company_type: 'mm_espinola')
      life_insurance = build(:life_insurance, employee:, life_insurance_policy: policy)

      expect(life_insurance).not_to be_valid
      expect(life_insurance.errors.full_messages).to eq(['Apólice deve ser da empresa do funcionário'])
    end

    it 'allows a single life insurance not excluded per employee' do
      existing = create(:life_insurance, included_on: Date.new(2025, 1, 1))

      expect(build(:life_insurance, employee: existing.employee)).not_to be_valid

      existing.update!(excluded_on: Date.new(2025, 6, 1))

      expect(build(:life_insurance, employee: existing.employee, included_on: Date.new(2026, 1, 1))).to be_valid
    end
  end

  describe 'coverages' do
    let(:policy) { create(:life_insurance_policy, company_type: 'mme') }
    let(:employee) { create(:employee, tenant: policy.tenant, company_type: 'mme') }

    it 'uses the capital of the policy when the life insurance has none' do
      life_insurance = create(:life_insurance, employee:, life_insurance_policy: policy, capital_cents: nil)

      expect(life_insurance).to have_attributes(
        capital: Money.from_cents(11_500_000), premium: Money.from_cents(3663),
        accidental_death: Money.from_cents(11_500_000), accidental_permanent_disability: Money.from_cents(11_500_000),
        functional_permanent_disability: Money.from_cents(11_500_000), spouse_death: Money.from_cents(5_750_000),
        children_death: Money.from_cents(1_150_000), funeral_assistance: Money.from_cents(600_000)
      )
    end

    it 'uses the capital of the life insurance when it has its own' do
      life_insurance = create(:life_insurance, employee:, life_insurance_policy: policy, capital_cents: 17_000_000)

      expect(life_insurance).to have_attributes(
        capital: Money.from_cents(17_000_000), premium: Money.from_cents(5415),
        spouse_death: Money.from_cents(8_500_000), children_death: Money.from_cents(1_700_000), funeral_assistance: Money.from_cents(600_000)
      )
    end
  end

  describe 'coverage period' do
    let(:tenant) { create(:tenant) }
    let!(:always) { create(:life_insurance, employee: create(:employee, tenant:, legal_id: nil)) }
    let!(:included) { create(:life_insurance, employee: create(:employee, tenant:, legal_id: nil), included_on: Date.new(2026, 5, 10)) }
    let!(:excluded) do
      create(:life_insurance, employee: create(:employee, tenant:, legal_id: nil), included_on: Date.new(2025, 1, 1),
                              excluded_on: Date.new(2026, 5, 10))
    end

    it 'covers from the inclusion and stops on the exclusion' do
      expect(described_class.covered_on(Date.new(2026, 5, 9))).to contain_exactly(always, excluded)
      expect(described_class.covered_on(Date.new(2026, 5, 10))).to contain_exactly(always, included)
      expect(excluded).to be_covered_on(Date.new(2026, 5, 9))
      expect(excluded).not_to be_covered_on(Date.new(2026, 5, 10))
      expect(included).not_to be_covered_on(Date.new(2026, 5, 9))
    end
  end
end
