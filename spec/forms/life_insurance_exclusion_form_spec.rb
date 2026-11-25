require 'rails_helper'

RSpec.describe LifeInsuranceExclusionForm do
  let(:life_insurance) { create(:life_insurance, included_on: Date.new(2026, 1, 5)) }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  it 'excludes on the given date' do
    form = described_class.new(life_insurance:, excluded_on: Date.new(2026, 11, 23))

    expect(form.save).to be(true)
    expect(life_insurance.reload.excluded_on).to eq(Date.new(2026, 11, 23))
  end

  it 'proposes today as the exclusion date' do
    expect(described_class.new(life_insurance:).excluded_on).to eq(Date.new(2026, 11, 24))
  end

  it 'rejects an exclusion before the inclusion' do
    form = described_class.new(life_insurance:, excluded_on: Date.new(2026, 1, 4))

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Data de exclusão não pode ser anterior à inclusão'])
    expect(life_insurance.reload.excluded_on).to be_nil
  end
end
