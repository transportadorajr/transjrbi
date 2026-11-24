require 'rails_helper'

RSpec.describe RiskAssessments::SeedCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '.call' do
    context 'when the employees of the payroll report are registered' do
      before { Employees::SeedCommand.call(tenant) }

      it 'registers the risk assessments of the Apisul and Opentech spreadsheets' do
        expect { described_class.call(tenant) }.to change(RiskAssessment, :count).by(119)

        expect(tenant.risk_assessments.group(:provider_type).count).to eq('apisul' => 64, 'opentech' => 55)
        expect(tenant.risk_assessments.group(:status_type).count).to eq('recommended' => 103, 'not_recommended' => 15, 'in_progress' => 1)
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00190').risk_assessments.order(:provider_type)
          .map { |risk_assessment| risk_assessment.slice(:provider_type, :status_type, :score, :valid_until).symbolize_keys })
          .to eq(
            [
              { provider_type: 'apisul', status_type: 'recommended', score: 60, valid_until: Date.new(2027, 1, 20) },
              { provider_type: 'opentech', status_type: 'recommended', score: nil, valid_until: nil },
            ],
          )
        expect(tenant.employees.find_by!(company_type: 'mm_espinola', registration: '00096').risk_assessments.sole)
          .to have_attributes(provider_type: 'apisul', status_type: 'in_progress', score: nil, valid_until: nil)
        expect(other_tenant.risk_assessments.count).to eq(0)
      end

      it 'can run again without duplicating the risk assessments' do
        described_class.call(tenant)

        expect { described_class.call(tenant) }.not_to change(RiskAssessment, :count)
      end

      it 'keeps a risk assessment already updated by the HR' do
        employee = tenant.employees.find_by!(company_type: 'mme', registration: '00190')
        updated = create(:risk_assessment, employee:, provider_type: 'apisul', score: 160, valid_until: Date.new(2027, 12, 1))

        described_class.call(tenant)

        expect(updated.reload).to have_attributes(score: 160, valid_until: Date.new(2027, 12, 1))
      end
    end

    it 'skips the risk assessments of employees that are not registered' do
      expect { described_class.call(tenant) }.not_to change(RiskAssessment, :count)
    end
  end
end
