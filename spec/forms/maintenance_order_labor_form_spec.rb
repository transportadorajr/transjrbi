require 'rails_helper'

RSpec.describe MaintenanceOrderLaborForm do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:) }
  let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }

  describe '#save' do
    it 'calculates the hours from the start and the end' do
      form = described_class.new(maintenance_order:, workshop_employee_id: mechanic.id, worked_on: '2026-11-11',
                                 start_time: '08:00', end_time: '10:45', hours: '9', activity: ' Troca das lonas ')

      expect { expect(form.save).to be(true) }.to change(MaintenanceOrderLabor, :count).by(1)

      labor = MaintenanceOrderLabor.last
      expect(labor).to have_attributes(tenant:, maintenance_order:, workshop_employee: mechanic, worked_on: Date.new(2026, 11, 11),
                                       hours: BigDecimal('2.75'), activity: 'Troca das lonas')
      expect([labor.start_time.strftime('%H:%M'), labor.end_time.strftime('%H:%M')]).to eq(%w[08:00 10:45])
    end

    it 'keeps the hours informed without start and end' do
      form = described_class.new(maintenance_order:, workshop_employee_id: mechanic.id, worked_on: '2026-11-11', hours: '1,5')

      expect(form.save).to be(true)
      expect(MaintenanceOrderLabor.last).to have_attributes(start_time: nil, end_time: nil, hours: BigDecimal('1.5'))
    end

    it 'rejects a labor without mechanic, day and hours' do
      form = described_class.new(maintenance_order:)

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrderLabor, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Mecânico não pode ficar em branco', 'Data não pode ficar em branco',
        'Horas deve ser informado quando não houver início e fim'
      )
    end

    it 'rejects an end before the start and a missing end' do
      form = described_class.new(maintenance_order:, workshop_employee_id: mechanic.id, worked_on: '2026-11-11',
                                 start_time: '10:00', end_time: '09:00')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Fim deve ser depois do início'])

      form = described_class.new(maintenance_order:, workshop_employee_id: mechanic.id, worked_on: '2026-11-11', start_time: '10:00')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Informe o início e o fim do trabalho, ou só as horas'])
    end

    it 'rejects an inactive employee or one of another tenant' do
      inactive = create(:workshop_employee, tenant:, active: false)
      stranger = create(:workshop_employee)

      [inactive, stranger].each do |employee|
        form = described_class.new(maintenance_order:, workshop_employee_id: employee.id, worked_on: '2026-11-11', hours: '1')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Mecânico não está cadastrado como funcionário ativo da oficina'])
      end
    end

    context 'when the labor already exists' do
      let!(:labor) { create(:maintenance_order_labor, maintenance_order:, workshop_employee: mechanic, hours: 2.5) }

      it 'keeps the mechanic after being deactivated and updates the labor' do
        mechanic.update!(active: false)
        form = described_class.for_item(labor)

        expect(form).to have_attributes(workshop_employee_id: mechanic.id, hours: '2,5', start_time: nil)

        form.assign_attributes(hours: '3')

        expect { expect(form.save).to be(true) }.not_to change(MaintenanceOrderLabor, :count)
        expect(labor.reload.hours).to eq(3)
      end
    end
  end
end
