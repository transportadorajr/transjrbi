require 'rails_helper'

RSpec.describe LifeInsurancePolicy do
  describe 'validations' do
    it 'requires a known company, a positive capital and a rate per mille' do
      policy = described_class.new(company_type: 'unknown', capital_cents: 0, premium_rate_per_mille: 0, funeral_assistance_cents: -1)

      expect(policy).not_to be_valid
      expect(policy.errors.attribute_names).to include(:company_type, :capital_cents, :premium_rate_per_mille, :funeral_assistance_cents)
    end

    it 'rejects percentages above 100' do
      policy = build(:life_insurance_policy, spouse_percentage: 101, children_percentage: 101)

      expect(policy).not_to be_valid
      expect(policy.errors.attribute_names).to contain_exactly(:spouse_percentage, :children_percentage)
    end

    it 'rejects a second policy of the same company for the tenant' do
      existing = create(:life_insurance_policy, company_type: 'mme')

      expect(build(:life_insurance_policy, tenant: existing.tenant, company_type: 'mme')).not_to be_valid
      expect(build(:life_insurance_policy, tenant: existing.tenant, company_type: 'mm_espinola')).to be_valid
      expect(build(:life_insurance_policy, company_type: 'mme')).to be_valid
    end
  end

  it 'translates the companies' do
    expect(described_class.company_types.keys.map { |company_type| described_class.human_enum_name(:company_type, company_type) })
      .to eq(['TransJR', 'MME', 'MM Espinola'])
  end

  it 'filters by company' do
    mme = create(:life_insurance_policy, company_type: 'mme')
    create(:life_insurance_policy, tenant: mme.tenant, company_type: 'transjr')

    expect(described_class.by_company_type('mme')).to eq([mme])
  end

  describe 'coverages' do
    let(:policy) { build(:life_insurance_policy) }

    it 'charges the premium per mille of the capital, rounded to the cent' do
      expect(policy.premium_cents(11_500_000)).to eq(3663)
      expect(policy.premium_cents(11_000_000)).to eq(3504)
      expect(policy.premium_cents(17_000_000)).to eq(5415)
    end

    it 'covers the spouse and the children with a share of the capital' do
      expect(policy.spouse_cents(11_500_000)).to eq(5_750_000)
      expect(policy.children_cents(11_500_000)).to eq(1_150_000)
    end
  end

  it 'cannot be destroyed while it has life insurances' do
    life_insurance = create(:life_insurance)

    expect(life_insurance.life_insurance_policy.destroy).to be(false)
    expect(life_insurance.life_insurance_policy.errors.full_messages).to eq(['Não é possível excluir uma apólice com seguros vinculados.'])
  end
end
