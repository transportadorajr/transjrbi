require 'rails_helper'

RSpec.describe JobPositionForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates an active job position with the normalized name' do
      form = described_class.new(tenant:, name: ' motorista   carreteiro ')

      expect { expect(form.save).to be(true) }.to change(JobPosition, :count).by(1)

      expect(JobPosition.last).to have_attributes(tenant:, name: 'MOTORISTA CARRETEIRO')
      expect(JobPosition.last).to be_activated
    end

    it 'rejects a job position without a name' do
      form = described_class.new(tenant:, name: ' ')

      expect { expect(form.save).to be_falsey }.not_to change(JobPosition, :count)
      expect(form.errors.full_messages).to eq(['Nome não pode ficar em branco'])
    end

    context 'when the name is already registered' do
      before do
        create(:job_position, tenant:, name: 'MOTORISTA')
        create(:job_position, name: 'MECÂNICO')
      end

      it 'rejects the same name in the tenant' do
        form = described_class.new(tenant:, name: 'Motorista')

        expect { expect(form.save).to be_falsey }.not_to change(JobPosition, :count)
        expect(form.errors.full_messages).to eq(['Nome já está em uso'])
      end

      it 'accepts a name registered only in another tenant' do
        expect(described_class.new(tenant:, name: 'Mecânico').save).to be(true)
      end
    end

    context 'when the job position is edited' do
      let!(:job_position) { create(:job_position, tenant:, name: 'MOTORISTA') }

      it 'keeps its own name available and renames it' do
        form = described_class.for_job_position(job_position)

        expect(form.save).to be(true)

        form.assign_attributes(name: 'motorista carreteiro', active: false)

        expect(form.save).to be(true)
        expect(job_position.reload.name).to eq('MOTORISTA CARRETEIRO')
        expect(job_position).not_to be_activated
      end

      it 'deactivates the job position' do
        expect(described_class.for_job_position(job_position).save_activation(false)).to be(true)
        expect(job_position.reload).not_to be_activated
      end
    end
  end
end
