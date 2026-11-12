require 'rails_helper'

RSpec.describe MaintenanceOrder do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 1) }

    it 'requires a number unique by tenant and the opening data' do
      order = build(:maintenance_order, tenant:, number: 1, plate: '', opened_at: nil, reported_defect: '')

      expect(order).not_to be_valid
      expect(order.errors.full_messages).to contain_exactly('Nº da OS já está em uso', 'Placa não pode ficar em branco',
                                                            'Abertura não pode ficar em branco',
                                                            'Defeito relatado não pode ficar em branco')
    end

    it 'accepts the same number in another tenant' do
      expect(build(:maintenance_order, number: 1)).to be_valid
    end

    it 'rejects unknown values in the enums' do
      order = build(:maintenance_order, tenant:, equipment_type: 'boat', priority_type: 'urgent', release_test_type: 'none')

      expect(order).not_to be_valid
      expect(order.errors.full_messages).to contain_exactly('Tipo de equipamento não está incluído na lista',
                                                            'Prioridade não está incluído na lista',
                                                            'Teste de liberação não está incluído na lista')
    end
  end

  describe 'enums' do
    it 'translates the classification of the maintenance' do
      order = build(:maintenance_order, equipment_type: 'road_train', maintenance_type: 'roadside', priority_type: 'high',
                                        execution_place_type: 'on_route', affected_system_type: 'pneumatic',
                                        release_test_type: 'yard_test', status_type: 'waiting_parts')

      expect(order).to have_attributes(equipment_type_name: 'Rodotrem', maintenance_type_name: 'Socorro (em rota)',
                                       priority_type_name: 'Alta', execution_place_type_name: 'Em rota',
                                       affected_system_type_name: 'Pneumático (ar)', release_test_type_name: 'Funcionamento em pátio',
                                       status_type_name: 'Aguardando peça')
    end
  end

  describe '#status_badge_kind' do
    it 'picks a color for each status' do
      expect(described_class::STATUSES.map { build(:maintenance_order, status_type: it).status_badge_kind })
        .to eq(%i[primary warning secondary success danger])
    end
  end

  describe 'status transitions' do
    let!(:maintenance_order) { create(:maintenance_order, tenant:) }

    it 'goes from open to in progress, waits for parts, resumes and finishes' do
      expect(maintenance_order.validate_start).to be(true)
      expect(maintenance_order.reload.status_type).to eq('in_progress')

      expect(maintenance_order.validate_wait_parts).to be(true)
      expect(maintenance_order.reload.status_type).to eq('waiting_parts')

      expect(maintenance_order.validate_start).to be(true)
      expect(maintenance_order.reload.status_type).to eq('in_progress')

      maintenance_order.finish!

      expect(maintenance_order.reload).to have_attributes(status_type: 'finished', editable?: false)
    end

    it 'cancels a pending order' do
      expect(maintenance_order.validate_cancel).to be(true)
      expect(maintenance_order.reload).to have_attributes(status_type: 'cancelled', editable?: false)
    end

    it 'refuses to change a finished order and explains why' do
      maintenance_order.update!(status_type: 'finished')

      expect(maintenance_order.validate_start).to be_nil
      expect(maintenance_order.validate_wait_parts).to be_nil
      expect(maintenance_order.validate_cancel).to be_nil
      expect(maintenance_order.errors.full_messages.uniq).to eq(['A OS não pode mudar de situação porque está concluída.'])
      expect(maintenance_order.reload.status_type).to eq('finished')
    end

    it 'does not wait for parts twice' do
      maintenance_order.update!(status_type: 'waiting_parts')

      expect(maintenance_order.validate_wait_parts).to be_nil
      expect(maintenance_order.errors.full_messages).to eq(['A OS não pode mudar de situação porque está aguardando peça.'])
    end
  end

  describe '.next_number' do
    it 'starts at one and follows the last number of the tenant' do
      expect(described_class.next_number(tenant)).to eq(1)

      create(:maintenance_order, tenant:, number: 41)
      create(:maintenance_order, number: 99)

      expect(described_class.next_number(tenant)).to eq(42)
    end
  end

  describe 'scopes' do
    let!(:open_order) { create(:maintenance_order, tenant:, plate: 'EXU1A23', vehicle_stopped: true, maintenance_type: 'preventive') }
    let!(:waiting_order) { create(:maintenance_order, tenant:, plate: 'GKT4567', status_type: 'waiting_parts', priority_type: 'high') }
    let!(:finished_order) { create(:maintenance_order, tenant:, plate: 'EXU9B87', status_type: 'finished', vehicle_stopped: true) }

    it 'filters the orders of the listing' do
      expect(described_class.by_number(waiting_order.number.to_s)).to eq([waiting_order])
      expect(described_class.by_plate('exu-1a')).to eq([open_order])
      expect(described_class.by_status_type('finished')).to eq([finished_order])
      expect(described_class.by_maintenance_type('preventive')).to eq([open_order])
      expect(described_class.by_priority_type('high')).to eq([waiting_order])
    end

    it 'filters the orders by affected system' do
      waiting_order.update!(affected_system_type: 'engine')

      expect(described_class.by_affected_system_type('engine')).to eq([waiting_order])
    end

    it 'filters the orders by opening period, including the whole last day' do
      open_order.update!(opened_at: Time.zone.local(2026, 11, 3, 0, 0))
      waiting_order.update!(opened_at: Time.zone.local(2026, 11, 5, 23, 59))
      finished_order.update!(opened_at: Time.zone.local(2026, 11, 6, 0, 0))

      expect(described_class.by_opened_from('2026-11-04')).to contain_exactly(waiting_order, finished_order)
      expect(described_class.by_opened_until('2026-11-05')).to contain_exactly(open_order, waiting_order)
      expect(described_class.by_opened_from('2026-11-03').by_opened_until('2026-11-03')).to eq([open_order])
    end

    it 'ignores an invalid opening date' do
      expect(described_class.by_opened_from('31/02/2026')).to contain_exactly(open_order, waiting_order, finished_order)
      expect(described_class.by_opened_until('')).to contain_exactly(open_order, waiting_order, finished_order)
    end

    it 'counts the pending orders and the stopped vehicles' do
      expect(described_class.pending).to contain_exactly(open_order, waiting_order)
      expect(described_class.stopped).to eq([open_order])
    end
  end

  describe '.enabled?' do
    it 'follows the maintenance flag of the tenant', flipper: :maintenance do
      expect(described_class.enabled?(tenant)).to be(true)

      Flipper.disable(:maintenance)

      expect(described_class.enabled?(tenant)).to be(false)
    end
  end
end
