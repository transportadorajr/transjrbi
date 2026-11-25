require 'rails_helper'

RSpec.describe LifeInsurancePolicyForm do
  let(:tenant) { create(:tenant) }
  let(:attributes) do
    { tenant:, company_type: 'transjr', capital: '100.000,00', premium_rate_per_mille: '0,3185', spouse_percentage: '50',
      children_percentage: '10', funeral_assistance: '6.000,00' }
  end

  describe '#save' do
    it 'creates the policy with the parsed values' do
      form = described_class.new(**attributes)

      expect { expect(form.save).to be(true) }.to change(LifeInsurancePolicy, :count).by(1)
      expect(LifeInsurancePolicy.last).to have_attributes(
        tenant:, company_type: 'transjr', capital_cents: 10_000_000, premium_rate_per_mille: BigDecimal('0.3185'),
        spouse_percentage: 50, children_percentage: 10, funeral_assistance_cents: 600_000
      )
    end

    it 'requires every field' do
      form = described_class.new(tenant:)

      expect(form.save).to be_falsey
      expect(form.errors.attribute_names)
        .to contain_exactly(:company_type, :capital, :premium_rate_per_mille, :spouse_percentage, :children_percentage, :funeral_assistance)
    end

    it 'rejects values out of range' do
      form = described_class.new(**attributes, capital: '0', premium_rate_per_mille: '1000', spouse_percentage: '101', children_percentage: '-1',
                                               funeral_assistance: '-5')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly(
        'Capital segurado deve ser maior que 0', 'Taxa do prêmio (‰) deve ser maior que 0 e menor que 1000',
        'Cônjuge (% do capital) deve estar entre 0 e 100', 'Filhos (% do capital) deve estar entre 0 e 100',
        'Assistência funeral familiar deve ser maior ou igual a 0'
      )
    end

    it 'rejects a second policy of the same company' do
      create(:life_insurance_policy, tenant:, company_type: 'transjr')

      form = described_class.new(**attributes)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Empresa já tem uma apólice cadastrada'])
    end

    it 'updates a policy keeping its company' do
      policy = create(:life_insurance_policy, tenant:, company_type: 'mme')
      form = described_class.for_life_insurance_policy(policy)
      form.assign_attributes(capital: '120.000,00', premium_rate_per_mille: '0,33')

      expect(form.save).to be(true)
      expect(policy.reload).to have_attributes(company_type: 'mme', capital_cents: 12_000_000, premium_rate_per_mille: BigDecimal('0.33'))
    end
  end

  describe '.for_life_insurance_policy' do
    it 'formats the values of the policy' do
      form = described_class.for_life_insurance_policy(build(:life_insurance_policy, tenant:))

      expect(form).to have_attributes(capital: '115.000,00', premium_rate_per_mille: '0,3185', spouse_percentage: '50', children_percentage: '10',
                                      funeral_assistance: '6.000,00')
    end
  end

  describe '#available_company_types' do
    it 'offers only the companies without a policy, keeping the company of the edited policy' do
      policy = create(:life_insurance_policy, tenant:, company_type: 'mme')
      create(:life_insurance_policy, company_type: 'transjr')

      expect(described_class.new(tenant:).available_company_types).to eq([['TransJR', 'transjr'], ['MM Espinola', 'mm_espinola']])
      expect(described_class.for_life_insurance_policy(policy).available_company_types)
        .to eq([['TransJR', 'transjr'], ['MME', 'mme'], ['MM Espinola', 'mm_espinola']])
    end
  end
end
