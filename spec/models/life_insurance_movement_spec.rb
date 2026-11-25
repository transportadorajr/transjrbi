require 'rails_helper'

RSpec.describe LifeInsuranceMovement do
  let(:tenant) { create(:tenant) }
  let(:policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
  let(:november) { '2026-11' }

  def insure(name, **attributes)
    employee = create(:employee, tenant:, name:, legal_id: nil, company_type: 'mme', born_on: Date.new(1984, 11, 21))
    create(:life_insurance, employee:, life_insurance_policy: policy, **attributes)
  end

  describe '.for_month' do
    it 'turns the inclusions, capital changes and exclusions of the month into movements' do
      included = insure('ANA', included_on: Date.new(2026, 11, 20))
      changed = insure('BRUNO', included_on: Date.new(2026, 1, 5), capital_changed_on: Date.new(2026, 11, 3))
      excluded = insure('CARLA', included_on: Date.new(2026, 1, 5), excluded_on: Date.new(2026, 11, 10))
      insure('DIEGO', included_on: Date.new(2026, 10, 31))
      insure('ELIS')

      movements = described_class.for_month(tenant.life_insurances, november)

      expect(movements.map { |movement| [movement.life_insurance, movement.kind, movement.code, movement.occurred_on] }).to eq(
        [[included, :inclusion, 1, Date.new(2026, 11, 20)], [changed, :change, 3, Date.new(2026, 11, 3)],
         [excluded, :exclusion, 2, Date.new(2026, 11, 10)]],
      )
    end

    it 'reports an inclusion and an exclusion of the same month, and no change for a capital set at the inclusion' do
      both = insure('ANA', included_on: Date.new(2026, 11, 2), capital_changed_on: Date.new(2026, 11, 5), excluded_on: Date.new(2026, 11, 28))

      expect(described_class.for_month(tenant.life_insurances, november).map(&:kind)).to eq(%i[inclusion exclusion])
      expect(described_class.for_month(tenant.life_insurances, november).map(&:life_insurance).uniq).to eq([both])
    end

    it 'falls back to the current month for an invalid month' do
      travel_to(Time.zone.local(2026, 11, 24, 10)) do
        insure('ANA', included_on: Date.new(2026, 11, 20))

        expect(described_class.for_month(tenant.life_insurances, 'invalid').map(&:kind)).to eq([:inclusion])
      end
    end
  end

  describe '#age' do
    it 'counts the full years on the movement date' do
      life_insurance = insure('ANA', included_on: Date.new(2026, 11, 20))

      expect(described_class.new(:inclusion, Date.new(2026, 11, 20), life_insurance).age).to eq(41)
      expect(described_class.new(:inclusion, Date.new(2026, 11, 21), life_insurance).age).to eq(42)
    end

    it 'has no age without the birth date' do
      life_insurance = insure('ANA')
      life_insurance.employee.update!(born_on: nil)

      expect(described_class.new(:exclusion, Date.new(2026, 11, 20), life_insurance).age).to be_nil
    end
  end

  it 'translates the movement kinds' do
    life_insurance = insure('ANA')

    expect(described_class::KINDS.keys.map { |kind| described_class.new(kind, Date.current, life_insurance).kind_name })
      .to eq(%w[Inclusão Exclusão Alteração])
  end
end
