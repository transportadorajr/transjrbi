require 'rails_helper'

RSpec.describe EmployeeForm do
  let(:tenant) { create(:tenant) }
  let(:attributes) do
    {
      tenant:, name: ' josé  da silva ', nickname: ' zé ', legal_id: '529.982.247-25', company_type: 'mm_espinola',
      registration: ' 0042 ', role: ' motorista ', cost_center: ' frota ', gender_type: 'male', born_on: '1980-05-10',
      admitted_on: '2015-03-02', work_schedule_type: 'five_two'
    }
  end

  describe '#save' do
    it 'creates an employee with the normalized fields' do
      form = described_class.new(**attributes)

      expect { expect(form.save).to be(true) }.to change(Employee, :count).by(1)

      expect(Employee.last).to have_attributes(
        tenant:, name: 'JOSÉ DA SILVA', nickname: 'ZÉ', legal_id: '52998224725', company_type: 'mm_espinola',
        registration: '0042', role: 'MOTORISTA', cost_center: 'FROTA', gender_type: 'male', born_on: Date.new(1980, 5, 10),
        admitted_on: Date.new(2015, 3, 2), work_schedule_type: 'five_two', driver: nil, workshop_employee: nil
      )
      expect(Employee.last).to be_activated
    end

    it 'rejects an employee without the required fields' do
      form = described_class.new(tenant:, name: ' ', legal_id: '', company_type: '', gender_type: '', work_schedule_type: '')

      expect { expect(form.save).to be_falsey }.not_to change(Employee, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Nome não pode ficar em branco', 'CPF não pode ficar em branco', 'Empresa não pode ficar em branco',
        'Sexo não pode ficar em branco', 'Escala não pode ficar em branco'
      )
    end

    it 'rejects an invalid CPF' do
      %w[529.982.247-24 111.111.111-11 1234].each do |legal_id|
        form = described_class.new(**attributes, legal_id:)

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['CPF não é válido'])
      end
    end

    it 'rejects an admission before the birth date' do
      form = described_class.new(**attributes, admitted_on: '1979-01-01')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Data de admissão deve ser posterior à data de nascimento'])
    end

    context 'when a transport document carries the CPF' do
      before { create(:atua_transport_document, tenant:, driver_code: 321, driver_document_digits: '52998224725') }

      it 'links the driver of the CPF found in the transport documents' do
        described_class.new(**attributes).save

        expect(Employee.last.driver_code).to eq(321)
      end
    end

    context 'when the tenant has a workshop employee' do
      let!(:mechanic) { create(:workshop_employee, tenant:) }

      it 'links the workshop employee' do
        expect(described_class.new(**attributes, workshop_employee_id: mechanic.id).save).to be(true)
        expect(Employee.last.workshop_employee).to eq(mechanic)
      end
    end

    context 'when the CPF is already registered' do
      before { create(:employee, tenant:, legal_id: '52998224725') }

      it 'rejects a CPF already registered' do
        form = described_class.new(**attributes)

        expect { expect(form.save).to be_falsey }.not_to change(Employee, :count)
        expect(form.errors.full_messages).to eq(['CPF já está cadastrado em outro funcionário'])
      end
    end

    context 'when the workshop employee is unavailable' do
      let!(:linked) { create(:workshop_employee, tenant:) }
      let!(:stranger) { create(:workshop_employee) }

      before { create(:employee, tenant:, legal_id: '11144477735', workshop_employee: linked) }

      it 'rejects a workshop employee linked to another employee or from another tenant' do
        [linked, stranger].each do |workshop_employee|
          form = described_class.new(**attributes, workshop_employee_id: workshop_employee.id)

          expect(form.save).to be_falsey
          expect(form.errors.full_messages).to eq(['Funcionário da oficina não é válido'])
        end
      end
    end

    context 'when the employee is edited' do
      let!(:mechanic) { create(:workshop_employee, tenant:) }
      let!(:employee) { create(:employee, tenant:, legal_id: '52998224725', workshop_employee: mechanic) }

      it 'keeps its own CPF and workshop employee available' do
        form = described_class.for_employee(employee)
        form.assign_attributes(name: 'José Novo', work_schedule_type: 'not_scheduled')

        expect(form.save).to be(true)
        expect(employee.reload).to have_attributes(name: 'JOSÉ NOVO', work_schedule_type: 'not_scheduled', workshop_employee: mechanic)
      end

      it 'deactivates the employee' do
        expect(described_class.for_employee(employee).save_activation(false)).to be(true)
        expect(employee.reload).not_to be_activated
      end
    end
  end
end
