require 'rails_helper'

RSpec.describe RiskAssessmentForm do
  let(:tenant) { create(:tenant) }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA') }

  describe '#save' do
    it 'creates the risk assessment of the employee' do
      form = described_class.new(tenant:, employee_id: jose.id, provider_type: 'apisul', status_type: '', score: 158,
                                 valid_until: Date.new(2027, 1, 20), notes: '  renovada   em janeiro ')

      expect { expect(form.save).to be(true) }.to change(RiskAssessment, :count).by(1)

      expect(RiskAssessment.last).to have_attributes(tenant:, employee: jose, provider_type: 'apisul', status_type: 'recommended', score: 158,
                                                     valid_until: Date.new(2027, 1, 20), notes: 'renovada em janeiro')
    end

    it 'requires the employee and the provider' do
      form = described_class.new(tenant:)

      expect { expect(form.save).to be_falsey }.not_to change(RiskAssessment, :count)
      expect(form.errors.full_messages).to eq(['Funcionário não pode ficar em branco', 'Gerenciadora não pode ficar em branco'])
    end

    it 'rejects a negative score' do
      form = described_class.new(tenant:, employee_id: jose.id, provider_type: 'apisul', score: -1)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Score deve ser maior ou igual a 0'])
    end

    it 'ignores an employee of another tenant' do
      stranger = create(:employee, name: 'FUNCIONÁRIO DE OUTRA')

      form = described_class.new(tenant:, employee_id: stranger.id, provider_type: 'apisul')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Funcionário não pode ficar em branco'])
    end

    context 'when the employee already has a risk assessment of the provider' do
      let!(:existing) { create(:risk_assessment, employee: jose, provider_type: 'opentech', status_type: 'recommended', score: nil) }

      it 'rejects a second one' do
        form = described_class.new(tenant:, employee_id: jose.id, provider_type: 'opentech')

        expect { expect(form.save).to be_falsey }.not_to change(RiskAssessment, :count)
        expect(form.errors.full_messages).to eq(['Gerenciadora já tem uma pesquisa cadastrada para este funcionário'])
      end

      it 'updates the existing one' do
        form = described_class.for_risk_assessment(existing)
        form.assign_attributes(status_type: 'not_recommended')

        expect(form.save).to be(true)
        expect(existing.reload).to have_attributes(provider_type: 'opentech', status_type: 'not_recommended')
      end
    end
  end
end
