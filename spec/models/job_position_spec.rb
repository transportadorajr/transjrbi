require 'rails_helper'

RSpec.describe JobPosition do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:truck_driver) { create(:job_position, tenant:, name: 'MOTORISTA') }

    it 'requires a name' do
      job_position = build(:job_position, tenant:, name: '')

      expect(job_position).not_to be_valid
      expect(job_position.errors.full_messages).to eq(['Nome não pode ficar em branco'])
    end

    it 'requires a name unique by tenant' do
      job_position = build(:job_position, tenant:, name: 'MOTORISTA')

      expect(job_position).not_to be_valid
      expect(job_position.errors.full_messages).to eq(['Nome já está em uso'])
    end

    it 'accepts the same name in another tenant' do
      expect(build(:job_position, name: 'MOTORISTA')).to be_valid
    end
  end

  describe 'scopes' do
    let!(:truck_driver) { create(:job_position, tenant:, name: 'MOTORISTA') }
    let!(:mechanic) { create(:job_position, tenant:, name: 'MECÂNICO', activated: false) }

    it 'filters by name and status' do
      expect(described_class.by_name('motor')).to eq([truck_driver])
      expect(described_class.by_status('active')).to eq([truck_driver])
      expect(described_class.by_status('deactivated')).to eq([mechanic])
    end
  end

  describe '.statuses' do
    it 'translates the statuses' do
      expect(described_class.statuses).to eq('Ativo' => :active, 'Inativo' => :deactivated)
    end
  end

  describe 'employees' do
    let!(:truck_driver) { create(:job_position, tenant:) }

    before { create(:employee, tenant:, job_position: truck_driver) }

    it 'cannot be destroyed while an employee holds it' do
      expect { truck_driver.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
