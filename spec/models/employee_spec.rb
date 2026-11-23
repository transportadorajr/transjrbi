require 'rails_helper'

RSpec.describe Employee do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'rejects a second employee with the same CPF in the tenant' do
      create(:employee, tenant:, legal_id: '52998224725')
      employee = build(:employee, tenant:, legal_id: '52998224725')

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['CPF já está em uso'])
    end

    it 'accepts the same CPF in another tenant' do
      create(:employee, legal_id: '52998224725')

      expect(build(:employee, tenant:, legal_id: '52998224725')).to be_valid
    end

    it 'rejects a driver already linked to another employee' do
      driver = create(:driver, tenant:)
      create(:employee, tenant:, legal_id: '52998224725', driver:)
      employee = build(:employee, tenant:, legal_id: '11144477735', driver:)

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['Motorista no Atua já está em uso'])
    end

    it 'rejects an unknown company' do
      employee = build(:employee, tenant:, company_type: 'other')

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['Empresa não está incluído na lista'])
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

  describe '#driver_code' do
    it 'returns the Atua code of the linked driver' do
      driver = create(:driver, tenant:, code: 4321)

      expect(build(:employee, tenant:, driver:).driver_code).to eq(4321)
      expect(build(:employee, tenant:).driver_code).to be_nil
    end
  end
end
