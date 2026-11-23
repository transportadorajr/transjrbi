require 'rails_helper'

RSpec.describe Employee do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'rejects an unknown company' do
      employee = build(:employee, tenant:, company_type: 'other')

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['Empresa não está incluído na lista'])
    end

    context 'when the tenant already has an employee with the CPF' do
      before { create(:employee, tenant:, legal_id: '52998224725') }

      it 'rejects a second employee with the same CPF in the tenant' do
        employee = build(:employee, tenant:, legal_id: '52998224725')

        expect(employee).not_to be_valid
        expect(employee.errors.full_messages).to eq(['CPF já está em uso'])
      end
    end

    context 'when another tenant has an employee with the CPF' do
      before { create(:employee, legal_id: '52998224725') }

      it 'accepts the same CPF in another tenant' do
        expect(build(:employee, tenant:, legal_id: '52998224725')).to be_valid
      end
    end

    context 'when the driver is linked to another employee' do
      let!(:driver) { create(:driver, tenant:) }

      before { create(:employee, tenant:, legal_id: '52998224725', driver:) }

      it 'rejects a driver already linked to another employee' do
        employee = build(:employee, tenant:, legal_id: '11144477735', driver:)

        expect(employee).not_to be_valid
        expect(employee.errors.full_messages).to eq(['Motorista no Atua já está em uso'])
      end
    end
  end

  describe 'scopes' do
    let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', nickname: 'NINA', legal_id: '52998224725', company_type: 'mme') }
    let!(:jose) do
      create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '11144477735', work_schedule_type: 'not_scheduled', activated: false)
    end

    it 'filters by name or nickname' do
      expect(described_class.by_name('nin')).to eq([ana])
      expect(described_class.by_name('silva')).to eq([jose])
    end

    it 'filters by company, schedule and status' do
      expect(described_class.by_company_type('mme')).to eq([ana])
      expect(described_class.by_work_schedule_type('not_scheduled')).to eq([jose])
      expect(described_class.by_status('active')).to eq([ana])
      expect(described_class.by_status('deactivated')).to eq([jose])
    end
  end

  describe '.scheduled_in' do
    let(:week) { Date.new(2026, 11, 22)..Date.new(2026, 11, 28) }
    let!(:scheduled) { create(:employee, tenant:, legal_id: '52998224725', admitted_on: Date.new(2020, 1, 6)) }
    let!(:without_admission) { create(:employee, tenant:, legal_id: '11144477735') }

    before do
      create(:employee, tenant:, legal_id: '39053344705', admitted_on: Date.new(2026, 11, 29))
      create(:employee, tenant:, legal_id: '86288366757', work_schedule_type: 'not_scheduled')
      create(:employee, tenant:, legal_id: '71428793860', activated: false)
    end

    it 'keeps the active 5x2 employees admitted until the end of the period' do
      expect(described_class.scheduled_in(week)).to contain_exactly(scheduled, without_admission)
    end
  end

  describe '#sunday_off_interval' do
    it 'gives a Sunday off every 15 days to women and every 28 days to men' do
      expect(build(:employee, gender_type: 'female').sunday_off_interval).to eq(15.days)
      expect(build(:employee, gender_type: 'male').sunday_off_interval).to eq(28.days)
    end
  end

  describe '#driver_code' do
    let!(:driver) { create(:driver, tenant:, code: 4321) }

    it 'returns the Atua code of the linked driver' do
      expect(build(:employee, tenant:, driver:).driver_code).to eq(4321)
      expect(build(:employee, tenant:).driver_code).to be_nil
    end
  end
end
