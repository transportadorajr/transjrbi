require 'rails_helper'

RSpec.describe WorkshopEmployeeForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates an active mechanic of the tenant' do
      form = described_class.new(tenant:, name: ' Carlos  Souza ')

      expect { expect(form.save).to be(true) }.to change(WorkshopEmployee, :count).by(1)

      expect(WorkshopEmployee.last).to have_attributes(tenant:, name: 'CARLOS SOUZA', role_type: 'mechanic', active: true)
    end

    it 'rejects an employee without a name or with an unknown role' do
      form = described_class.new(tenant:, name: ' ', role_type: 'driver')

      expect { expect(form.save).to be_falsey }.not_to change(WorkshopEmployee, :count)
      expect(form.errors.full_messages).to contain_exactly('Nome não pode ficar em branco', 'Função não está incluído na lista')
    end

    context 'when the name is already registered' do
      let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }

      it 'rejects another employee with the same name' do
        form = described_class.new(tenant:, name: 'carlos souza')

        expect { expect(form.save).to be_falsey }.not_to change(WorkshopEmployee, :count)
        expect(form.errors.full_messages).to eq(['Nome já está cadastrado'])
      end

      it 'accepts the same name in another tenant' do
        form = described_class.new(tenant: create(:tenant), name: 'CARLOS SOUZA')

        expect { expect(form.save).to be(true) }.to change(WorkshopEmployee, :count).by(1)
      end

      it 'updates the employee keeping its own name' do
        form = described_class.for_workshop_employee(carlos)
        form.assign_attributes(role_type: 'supervisor', active: false)

        expect { expect(form.save).to be(true) }.not_to change(WorkshopEmployee, :count)
        expect(carlos.reload).to have_attributes(name: 'CARLOS SOUZA', role_type: 'supervisor', active: false)
      end
    end
  end
end
