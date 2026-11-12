require 'rails_helper'

RSpec.describe WorkshopEmployee do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS') }

    it 'requires a name unique by tenant' do
      employee = build(:workshop_employee, tenant:, name: 'CARLOS')

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['Nome já está em uso'])
      expect(build(:workshop_employee, tenant:, name: '')).not_to be_valid
    end

    it 'accepts the same name in another tenant' do
      expect(build(:workshop_employee, name: 'CARLOS')).to be_valid
    end

    it 'rejects an unknown role' do
      employee = build(:workshop_employee, tenant:, role_type: 'driver')

      expect(employee).not_to be_valid
      expect(employee.errors.full_messages).to eq(['Função não está incluído na lista'])
    end
  end

  describe 'enums' do
    it 'translates the role' do
      expect(build(:workshop_employee, role_type: 'supervisor').role_type_name).to eq('Encarregado')
      expect(build(:workshop_employee, role_type: 'mechanic').role_type_name).to eq('Mecânico')
    end
  end

  describe 'scopes' do
    let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
    let!(:paulo) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor', active: false) }

    it 'filters by name, role and activity' do
      expect(described_class.by_name('souza')).to eq([carlos])
      expect(described_class.by_role_type('supervisor')).to eq([paulo])
      expect(described_class.active).to eq([carlos])
    end
  end

  describe 'deletion' do
    let!(:supervisor) { create(:workshop_employee, tenant:, role_type: 'supervisor') }
    let!(:maintenance_order) { create(:maintenance_order, tenant:, supervisor:) }

    it 'keeps an employee that is already on a maintenance order' do
      expect(supervisor.destroy).to be(false)
      expect(supervisor.errors.full_messages).to be_present
    end
  end
end
