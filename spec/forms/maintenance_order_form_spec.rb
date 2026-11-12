require 'rails_helper'

RSpec.describe MaintenanceOrderForm do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant:, name: 'Rafael Oficina') }
  let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU1A23', driver_code: 501, driver_name: 'JOSE DA SILVA') }
  let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
  let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }

  let(:attributes) do
    { plate: 'exu-1a23', opened_at: '2026-11-11T08:30', odometer_km: '452300', hour_meter: '', driver_code: '501',
      supervisor_id: supervisor.id.to_s, equipment_type: 'truck_tractor', maintenance_type: 'corrective', priority_type: 'high',
      vehicle_stopped: '1', execution_place_type: 'internal_workshop', affected_system_type: 'brakes',
      reported_defect: " Freio puxando para a direita \n", diagnosis: '', performed_service: '' }
  end

  describe '#save' do
    it 'opens a maintenance order with the next number of the tenant' do
      create(:maintenance_order, tenant:, number: 7)
      form = described_class.new(tenant:, opened_by: user, **attributes)

      expect { expect(form.save).to be(true) }.to change(MaintenanceOrder, :count).by(1)

      expect(form.maintenance_order).to have_attributes(
        tenant:, number: 8, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 11, 8, 30), odometer_km: 452_300,
        hour_meter: nil, driver_code: 501, driver_name: 'JOSE DA SILVA', supervisor:, opened_by: user,
        equipment_type: 'truck_tractor', equipment_other: nil, maintenance_type: 'corrective', priority_type: 'high',
        vehicle_stopped: true, execution_place_type: 'internal_workshop', affected_system_type: 'brakes',
        reported_defect: 'Freio puxando para a direita', diagnosis: nil, performed_service: nil, status_type: 'open'
      )
    end

    it 'starts the numbering at one' do
      form = described_class.new(tenant:, opened_by: user, **attributes)

      expect(form.save).to be(true)
      expect(form.maintenance_order.number).to eq(1)
    end

    it 'keeps the description of another equipment only when the type is other' do
      form = described_class.new(tenant:, **attributes, equipment_type: 'other', equipment_other: ' guindaste ')

      expect(form.save).to be(true)
      expect(form.maintenance_order).to have_attributes(equipment_type: 'other', equipment_other: 'GUINDASTE')

      form = described_class.new(tenant:, **attributes, equipment_other: 'GUINDASTE')

      expect(form.save).to be(true)
      expect(form.maintenance_order.equipment_other).to be_nil
    end

    it 'rejects an order without the required fields' do
      form = described_class.new(tenant:, plate: '', opened_at: '', reported_defect: ' ', priority_type: 'urgent',
                                 execution_place_type: '')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrder, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Placa não pode ficar em branco', 'Data e hora de abertura não pode ficar em branco',
        'Tipo de equipamento não pode ficar em branco', 'Tipo de manutenção não pode ficar em branco',
        'Local de execução não pode ficar em branco', 'Sistema afetado não pode ficar em branco',
        'Defeito relatado não pode ficar em branco', 'Prioridade não está incluído na lista'
      )
    end

    it 'rejects an unregistered plate, an unknown driver, a mechanic as supervisor and a missing other equipment' do
      form = described_class.new(tenant:, **attributes, plate: 'AB123', driver_code: '999', supervisor_id: mechanic.id.to_s,
                                 equipment_type: 'other', odometer_km: '-1')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly(
        'Placa não está cadastrada no Atua', 'Motorista não foi encontrado no Atua',
        'Encarregado responsável não está cadastrado como encarregado', 'Outro equipamento não pode ficar em branco',
        'KM deve ser maior ou igual a 0'
      )
    end

    it 'accepts a foreign plate registered in Atua' do
      create(:atua_vehicle, tenant:, plate: 'AAOP898')
      form = described_class.new(tenant:, **attributes, plate: 'aaop 898')

      expect { expect(form.save).to be(true) }.to change(MaintenanceOrder, :count).by(1)
      expect(form.maintenance_order.plate).to eq('AAOP898')
    end

    it 'rejects a plate removed from Atua or registered only in another tenant' do
      create(:atua_vehicle, tenant:, plate: 'CCS276', removed_from_atua_at: 1.day.ago)
      create(:atua_vehicle, plate: 'KOLA002')

      expect(described_class.new(tenant:, **attributes, plate: 'CCS276').save).to be_falsey
      expect(described_class.new(tenant:, **attributes, plate: 'KOLA002').save).to be_falsey
      expect(MaintenanceOrder.count).to eq(0)
    end

    it 'does not accept the supervisor of another tenant' do
      stranger = create(:workshop_employee, role_type: 'supervisor')
      form = described_class.new(tenant:, **attributes, supervisor_id: stranger.id.to_s)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Encarregado responsável não está cadastrado como encarregado'])
    end

    context 'when the order already exists' do
      let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 3, opened_by: user) }

      it 'keeps the plate of the order after its vehicle is removed from Atua' do
        vehicle.update!(removed_from_atua_at: 1.day.ago)
        form = described_class.for_maintenance_order(maintenance_order)
        form.assign_attributes(diagnosis: 'Lonas gastas', driver_code: '')

        expect(form.save).to be(true)
        expect(maintenance_order.reload).to have_attributes(plate: 'EXU1A23', diagnosis: 'Lonas gastas')
      end

      it 'updates the order keeping its number and who opened it' do
        form = described_class.for_maintenance_order(maintenance_order)
        form.assign_attributes(diagnosis: 'Lonas gastas', performed_service: 'Troca das lonas', driver_code: '501')

        expect { expect(form.save).to be(true) }.not_to change(MaintenanceOrder, :count)
        expect(maintenance_order.reload).to have_attributes(number: 3, opened_by: user, diagnosis: 'Lonas gastas',
                                                            performed_service: 'Troca das lonas', driver_name: 'JOSE DA SILVA',
                                                            reported_defect: 'Freio puxando para a direita')
      end
    end
  end
end
