require 'rails_helper'

RSpec.describe Dashboard::HrPendencies do
  subject(:dashboard) { described_class.new(tenant:) }

  let(:tenant) { create(:tenant) }
  let!(:ana) { create(:employee, tenant:, name: 'ANA', legal_id: nil) }
  let!(:bruno) { create(:employee, tenant:, name: 'BRUNO', legal_id: nil) }
  let!(:carlos) { create(:employee, tenant:, name: 'CARLOS', legal_id: nil) }
  let!(:diego) { create(:employee, tenant:, name: 'DIEGO', legal_id: nil) }
  let!(:edson) { create(:employee, tenant:, name: 'EDSON', legal_id: nil, admitted_on: Date.new(2024, 10, 1)) }
  let!(:fabio) { create(:employee, tenant:, name: 'FABIO', legal_id: nil, admitted_on: Date.new(2025, 1, 10)) }
  let!(:gustavo) { create(:employee, tenant:, name: 'GUSTAVO', legal_id: nil) }

  around { |example| travel_to(Time.zone.local(2026, 11, 25, 10)) { example.run } }

  before do
    [ana, carlos, diego, edson, fabio, gustavo].each { |employee| create(:life_insurance, employee:) }
    [ana, bruno, diego, edson, fabio, gustavo].each { |employee| create(:emergency_contact, employee:) }
    create(:risk_assessment, employee: ana, valid_until: Date.new(2027, 5, 11))
    create(:risk_assessment, employee: diego, provider_type: 'apisul', valid_until: Date.new(2026, 11, 24))
    create(:risk_assessment, employee: diego, provider_type: 'opentech', score: nil, valid_until: Date.new(2026, 12, 10))
    create(:work_schedule_day, employee: gustavo, date: Date.new(2026, 10, 4))
    create(:employee, tenant:, name: 'HELENA', legal_id: nil, activated: false)
    create(:employee, name: 'IVO DE OUTRA')
  end

  def rows
    dashboard.rows(tenant.employees.order(:name))
  end

  it 'lists the active employees with something to solve and what is missing for each one' do
    expect(rows.map { |row| [row.employee.name, row.pendencies] }).to eq(
      [
        ['BRUNO', %i[uninsured]],
        ['CARLOS', %i[missing_emergency_contact]],
        ['DIEGO', %i[risk_assessment_expired risk_assessment_expiring]],
        ['EDSON', %i[vacation_overdue]],
        ['FABIO', %i[vacation_due_soon]],
        ['GUSTAVO', %i[irregular_days_off]],
      ],
    )
  end

  it 'filters and counts the employees by pendency' do
    expect(dashboard.with_kind(rows, 'vacation_overdue').map { |row| row.employee.name }).to eq(['EDSON'])
    expect(dashboard.with_kind(rows, 'anything').size).to eq(6)
    expect(dashboard.counts(rows)).to eq(
      uninsured: 1, missing_emergency_contact: 1, risk_assessment_expired: 1, risk_assessment_expiring: 1, vacation_overdue: 1,
      vacation_due_soon: 1, irregular_days_off: 1
    )
  end

  it 'does not count the schedule of the next week as an irregular day off' do
    travel_to(Time.zone.local(2026, 11, 27, 10))

    expect(rows.map { |row| row.employee.name }).not_to include('ANA')
  end

  context 'when only some pendencies are checked' do
    subject(:dashboard) { described_class.new(tenant:, kinds: %i[uninsured missing_emergency_contact]) }

    it 'lists only the employees with those pendencies' do
      expect(rows.map { |row| [row.employee.name, row.pendencies] }).to eq([['BRUNO', %i[uninsured]], ['CARLOS', %i[missing_emergency_contact]]])
      expect(dashboard.counts(rows)).to eq(uninsured: 1, missing_emergency_contact: 1)
    end
  end

  describe '.kinds_for' do
    let(:user) { create(:user, tenant:) }

    before do
      create(:access, user:, resource: create(:resource, slug: 'life_insurances'))
      create(:access, user:, resource: create(:resource, slug: 'vacations'))
    end

    it 'keeps only the pendencies of the screens the user can read' do
      expect(described_class.kinds_for(Ability.new(user))).to eq(%i[uninsured vacation_overdue vacation_due_soon])
    end
  end
end
