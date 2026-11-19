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
    context 'with parts and services' do
      let!(:supplier) { create(:supplier, tenant:) }
      let!(:lining) { create(:maintenance_part, tenant:, description: 'LONA DE FREIO', unit: 'UN', unit_price_cents: 8_500) }

      it 'opens the order with its items and totals, ignoring blank rows' do
        form = described_class.new(
          tenant:, opened_by: user, **attributes,
          parts_attributes: { '0' => { maintenance_part_id: lining.id.to_s, quantity: '2', source_type: 'stock' },
                              '1' => { source_type: 'stock', description: ' ', quantity: '' } },
          services_attributes: { '0' => { supplier_id: supplier.id.to_s, description: 'Retífica', quoted: '450,00' } }
        )

        expect { expect(form.save).to be(true) }.to change(MaintenanceOrderPart, :count).by(1).and change(MaintenanceOrderService, :count).by(1)

        expect(form.maintenance_order.parts.sole).to have_attributes(maintenance_part: lining, description: 'LONA DE FREIO', total_cents: 17_000)
        expect(form.maintenance_order.reload).to have_attributes(parts_total_cents: 17_000, services_total_cents: 45_000, total_cents: 62_000)
      end

      it 'does not open the order when an item is invalid' do
        form = described_class.new(tenant:, opened_by: user, **attributes,
                                   parts_attributes: { '0' => { description: 'Lona', quantity: '0', source_type: 'stock' } })

        expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrder, :count)
        expect(form.errors.full_messages).to eq(['Peça 1: Quantidade deve ser maior que 0'])
        expect(form.parts.sole.errors.full_messages).to eq(['Quantidade deve ser maior que 0'])
      end
    end

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

    it 'keeps the estimated completion of the order' do
      form = described_class.new(tenant:, **attributes, estimated_completion_at: '2026-11-12T17:00')

      expect(form.save).to be(true)
      expect(form.maintenance_order.estimated_completion_at).to eq(Time.zone.local(2026, 11, 12, 17))
    end

    it 'rejects an estimated completion before the opening' do
      form = described_class.new(tenant:, **attributes, estimated_completion_at: '2026-11-11T08:00')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrder, :count)
      expect(form.errors.full_messages).to eq(['Previsão de término não pode ser antes da abertura da OS'])
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

    context 'with mechanics' do
      let!(:helper) { create(:workshop_employee, tenant:, name: 'ANDRE ROCHA') }

      it 'saves every chosen active workshop employee as a mechanic of the order' do
        form = described_class.new(tenant:, opened_by: user, **attributes, mechanic_ids: ['', mechanic.id.to_s, helper.id.to_s])

        expect { expect(form.save).to be(true) }.to change(MaintenanceOrder, :count).by(1).and change(MaintenanceOrderMechanic, :count).by(2)
        expect(MaintenanceOrder.last.mechanics).to eq([helper, mechanic])
      end

      it 'opens the order without mechanics' do
        form = described_class.new(tenant:, opened_by: user, **attributes, mechanic_ids: [''])

        expect(form.save).to be(true)
        expect(form.maintenance_order.mechanics).to be_empty
      end

      it 'rejects an inactive employee or one of another tenant' do
        inactive = create(:workshop_employee, tenant:, name: 'ANTONIO RAMOS', active: false)
        stranger = create(:workshop_employee, name: 'OUTRO TENANT')

        [inactive, stranger].each do |employee|
          form = described_class.new(tenant:, **attributes, mechanic_ids: [mechanic.id.to_s, employee.id.to_s])

          expect(form.save).to be_falsey
          expect(form.errors.full_messages).to eq(['Mecânicos contém funcionário que não está ativo na oficina'])
        end
        expect(MaintenanceOrder.count).to eq(0)
        expect(MaintenanceOrderMechanic.count).to eq(0)
      end
    end

    context 'when the order already exists' do
      let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 3, opened_by: user) }

      it 'keeps a mechanic after the employee is deactivated' do
        create(:maintenance_order_mechanic, maintenance_order:, workshop_employee: mechanic)
        mechanic.update!(active: false)
        form = described_class.for_maintenance_order(maintenance_order)
        form.assign_attributes(diagnosis: 'Lonas gastas')

        expect(form.save).to be(true)
        expect(maintenance_order.reload).to have_attributes(mechanics: [mechanic], diagnosis: 'Lonas gastas')
      end

      it 'adds and removes mechanics of the order' do
        helper = create(:workshop_employee, tenant:, name: 'ANDRE ROCHA')
        electrician = create(:workshop_employee, tenant:, name: 'BRUNO DIAS')
        create(:maintenance_order_mechanic, maintenance_order:, workshop_employee: mechanic)
        create(:maintenance_order_mechanic, maintenance_order:, workshop_employee: helper)
        form = described_class.for_maintenance_order(maintenance_order)

        expect(form.mechanic_ids).to contain_exactly(mechanic.id, helper.id)

        form.assign_attributes(mechanic_ids: [helper.id.to_s, electrician.id.to_s])

        expect { expect(form.save).to be(true) }.not_to change(MaintenanceOrderMechanic, :count)
        expect(maintenance_order.reload.mechanics).to eq([helper, electrician])
      end

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
