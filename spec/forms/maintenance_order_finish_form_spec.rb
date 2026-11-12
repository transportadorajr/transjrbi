require 'rails_helper'

RSpec.describe MaintenanceOrderFinishForm do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) do
    create(:maintenance_order, tenant:, status_type: 'in_progress', odometer_km: 452_300, opened_at: Time.zone.local(2026, 11, 11, 8),
                               performed_service: 'Troca das lonas')
  end

  describe '.for_maintenance_order' do
    it 'suggests the current time and the service already written' do
      travel_to(Time.zone.local(2026, 11, 11, 17, 42, 31)) do
        form = described_class.for_maintenance_order(maintenance_order)

        expect(form).to have_attributes(finished_at: Time.zone.local(2026, 11, 11, 17, 42), performed_service: 'Troca das lonas')
      end
    end
  end

  describe '.enum_options_for_select' do
    it 'translates the release tests like the order' do
      expect(described_class.enum_options_for_select(:release_test_type))
        .to eq([['Rodagem', 'road_test'], ['Funcionamento em pátio', 'yard_test'], ['Não se aplica', 'not_applicable']])
    end
  end

  describe '#save' do
    it 'finishes the order with the closing data' do
      form = described_class.new(maintenance_order:, finished_at: '2026-11-11T17:30', release_test_type: 'road_test',
                                 next_preventive_km: '482300', performed_service: " Troca das lonas e regulagem \n")

      expect(form.save).to be(true)
      expect(maintenance_order.reload).to have_attributes(
        status_type: 'finished', finished_at: Time.zone.local(2026, 11, 11, 17, 30), release_test_type: 'road_test',
        next_preventive_km: 482_300, performed_service: 'Troca das lonas e regulagem'
      )
    end

    it 'rejects a closing without the required data' do
      form = described_class.new(maintenance_order:, finished_at: '', release_test_type: 'flight', performed_service: ' ')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Data e hora de conclusão não pode ficar em branco',
                                                           'Teste de liberação não está incluído na lista',
                                                           'Serviço executado não pode ficar em branco')
      expect(maintenance_order.reload.status_type).to eq('in_progress')
    end

    it 'rejects a conclusion before the opening and a preventive behind the odometer' do
      form = described_class.new(maintenance_order:, finished_at: '2026-11-10T17:30', release_test_type: 'yard_test',
                                 next_preventive_km: '400000', performed_service: 'Troca')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Data e hora de conclusão não pode ser antes da abertura da OS',
                                                           'Próxima preventiva (km) deve ser maior que o KM da abertura')
    end

    it 'does not finish an order already cancelled' do
      maintenance_order.update!(status_type: 'cancelled')
      form = described_class.new(maintenance_order:, finished_at: '2026-11-11T17:30', release_test_type: 'not_applicable',
                                 performed_service: 'Troca')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['A OS não pode ser encerrada porque está cancelada.'])
      expect(maintenance_order.reload.status_type).to eq('cancelled')
    end
  end
end
