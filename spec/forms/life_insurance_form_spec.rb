require 'rails_helper'

RSpec.describe LifeInsuranceForm do
  let(:tenant) { create(:tenant) }
  let!(:policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
  let!(:employee) { create(:employee, tenant:, company_type: 'mme', legal_id: '52998224725', born_on: Date.new(1990, 5, 1)) }

  describe '#save on create' do
    it 'includes the employee with the policy of the company' do
      form = described_class.new(tenant:, employee_id: employee.id, included_on: Date.new(2026, 11, 20))

      expect { expect(form.save).to be(true) }.to change(LifeInsurance, :count).by(1)
      expect(LifeInsurance.last).to have_attributes(tenant:, employee:, life_insurance_policy: policy, included_on: Date.new(2026, 11, 20),
                                                    capital_changed_on: nil)
      expect(LifeInsurance.last[:capital_cents]).to be_nil
    end

    it 'keeps an own capital' do
      form = described_class.new(tenant:, employee_id: employee.id, included_on: Date.new(2026, 11, 20), capital: '170.000,00')

      expect(form.save).to be(true)
      expect(LifeInsurance.last.capital_cents).to eq(17_000_000)
    end

    it 'requires the employee and the inclusion date' do
      form = described_class.new(tenant:)

      expect(form.save).to be_falsey
      expect(form.errors.attribute_names).to contain_exactly(:employee, :included_on)
    end

    it 'rejects an inactive or already insured employee' do
      create(:life_insurance, employee:, life_insurance_policy: policy)
      employee.update!(activated: false)
      form = described_class.new(tenant:, employee_id: employee.id, included_on: Date.new(2026, 11, 20))

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Funcionário está inativo e não pode ser incluído no seguro',
                                                           'Funcionário já está incluído no seguro de vida')
    end

    it 'requires the data the insurer needs and the policy of the company' do
      employee.update!(born_on: nil, company_type: 'transjr')
      form = described_class.new(tenant:, employee_id: employee.id, included_on: Date.new(2026, 11, 20))

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly(
        'Funcionário precisa ter CPF e data de nascimento cadastrados para a seguradora',
        'Funcionário é da empresa TransJR, que ainda não tem apólice cadastrada',
      )
    end

    it 'rejects a capital that is not positive' do
      form = described_class.new(tenant:, employee_id: employee.id, included_on: Date.new(2026, 11, 20), capital: '0')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Capital próprio deve ser maior que 0'])
    end
  end

  describe '#save on update' do
    let!(:life_insurance) { create(:life_insurance, employee:, life_insurance_policy: policy, included_on: Date.new(2026, 1, 5)) }

    it 'records the date of a capital change' do
      form = described_class.for_life_insurance(life_insurance)
      form.assign_attributes(capital: '200.000,00', capital_changed_on: Date.new(2026, 11, 15))

      expect(form.save).to be(true)
      expect(life_insurance.reload).to have_attributes(capital_cents: 20_000_000, capital_changed_on: Date.new(2026, 11, 15))
    end

    it 'requires a change date on or after the inclusion when the capital changes' do
      form = described_class.for_life_insurance(life_insurance)
      form.assign_attributes(capital: '200.000,00')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Vigência do novo capital não pode ficar em branco'])

      form.capital_changed_on = Date.new(2025, 12, 31)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Vigência do novo capital não pode ser anterior à inclusão'])
    end

    it 'keeps the change date when the capital does not change' do
      form = described_class.for_life_insurance(life_insurance)
      form.assign_attributes(included_on: Date.new(2026, 2, 1), capital_changed_on: Date.new(2026, 11, 15))

      expect(form.save).to be(true)
      expect(life_insurance.reload).to have_attributes(included_on: Date.new(2026, 2, 1), capital_changed_on: nil)
    end

    it 'edits a seeded life insurance without inclusion date or insurer data' do
      employee.update!(born_on: nil)
      seeded = create(:life_insurance, employee: create(:employee, tenant:, company_type: 'mme', legal_id: nil), life_insurance_policy: policy)
      form = described_class.for_life_insurance(seeded)
      form.assign_attributes(capital: '120.000,00', capital_changed_on: Date.new(2026, 11, 1))

      expect(form.save).to be(true)
      expect(seeded.reload).to have_attributes(included_on: nil, capital_cents: 12_000_000, capital_changed_on: Date.new(2026, 11, 1))
    end
  end

  describe '#available_employees' do
    it 'offers the active employees without an open life insurance' do
      create(:life_insurance, employee:, life_insurance_policy: policy)
      free = create(:employee, tenant:, name: 'LIVRE', legal_id: '11144477735')
      excluded = create(:employee, tenant:, name: 'EXCLUIDO', legal_id: '39053344705', company_type: 'mme')
      create(:life_insurance, employee: excluded, life_insurance_policy: policy, excluded_on: Date.new(2026, 1, 1))
      create(:employee, tenant:, name: 'INATIVO', legal_id: '86288366757', activated: false)

      expect(described_class.new(tenant:).available_employees).to eq([excluded, free])
    end
  end
end
