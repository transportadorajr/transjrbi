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

  context 'when the signatures are required', flipper: :maintenance_order_signatures do
    let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
    let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
    let!(:ana) { create(:workshop_employee, tenant:, name: 'ANA COSTA') }
    let!(:finisher) { create(:user, tenant:) }
    let!(:carlos_morning) { create(:maintenance_order_labor, maintenance_order:, workshop_employee: carlos, worked_on: Date.new(2026, 11, 11)) }
    let!(:carlos_afternoon) do
      create(:maintenance_order_labor, maintenance_order:, workshop_employee: carlos, worked_on: Date.new(2026, 11, 12))
    end
    let!(:ana_labor) { create(:maintenance_order_labor, maintenance_order:, workshop_employee: ana) }

    let(:closing) { { finished_at: '2026-11-11T17:30', release_test_type: 'road_test', performed_service: 'Troca das lonas' } }

    def finish_form(**attributes)
      described_class.new(maintenance_order:, finished_by: finisher, ip_address: '10.0.0.7', user_agent: 'Mobile Safari', **closing,
                          **attributes)
    end

    it 'finishes the order with the signature of the supervisor and of each mechanic of the labor' do
      travel_to(Time.zone.local(2026, 11, 11, 17, 31)) do
        form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: signature_strokes,
                           mechanic_signatures: { carlos.id.to_s => signature_strokes, ana.id.to_s => signature_strokes })

        expect { expect(form.save).to be(true) }.to change(MaintenanceOrderSignature, :count).by(3)
      end

      expect(maintenance_order.reload).to have_attributes(status_type: 'finished', supervisor:)
      signatures = maintenance_order.signatures.order(:signer_role_type, :signer_name)
      expect(signatures.map { |signature| [signature.signer_role_type, signature.signer_name, signature.workshop_employee] })
        .to eq([['supervisor', 'PAULO LIMA', supervisor], ['mechanic', 'ANA COSTA', ana], ['mechanic', 'CARLOS SOUZA', carlos]])
      expect(signatures).to all(have_attributes(tenant:, strokes: SignatureHelpers::SAMPLE_STROKES, signed_by: finisher,
                                                signed_at: Time.zone.local(2026, 11, 11, 17, 31), ip_address: '10.0.0.7',
                                                user_agent: 'Mobile Safari', content_digest: maintenance_order.content_digest))
    end

    it 'rejects a closing without the supervisor nor the signatures' do
      form = finish_form(supervisor_id: '', supervisor_signature: '',
                         mechanic_signatures: { carlos.id.to_s => [[[0.1, 0.1]]].to_json })

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrderSignature, :count)
      expect(form.errors.full_messages).to contain_exactly('Encarregado não pode ficar em branco',
                                                           'Falta a assinatura de ANA COSTA.', 'Falta a assinatura de CARLOS SOUZA.')
      expect(maintenance_order.reload.status_type).to eq('in_progress')
    end

    it 'rejects a supervisor that did not sign and an employee who is not a supervisor' do
      form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: '<svg/>',
                         mechanic_signatures: { carlos.id.to_s => signature_strokes, ana.id.to_s => signature_strokes })

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Assinatura do encarregado não pode ficar em branco'])

      form = finish_form(supervisor_id: carlos.id.to_s, supervisor_signature: signature_strokes,
                         mechanic_signatures: { carlos.id.to_s => signature_strokes, ana.id.to_s => signature_strokes })

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Encarregado não está cadastrado como encarregado ativo'])
    end

    it 'ignores signatures of employees outside the labor' do
      stranger = create(:workshop_employee, tenant:, name: 'ZECA')
      form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: signature_strokes,
                         mechanic_signatures: { carlos.id.to_s => signature_strokes, ana.id.to_s => signature_strokes,
                                                stranger.id.to_s => signature_strokes })

      expect(form.save).to be(true)
      expect(maintenance_order.signatures.pluck(:signer_name)).to contain_exactly('PAULO LIMA', 'ANA COSTA', 'CARLOS SOUZA')
    end

    it 'lets the supervisor sign twice when the supervisor also worked on the order' do
      create(:maintenance_order_labor, maintenance_order:, workshop_employee: supervisor)
      form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: signature_strokes,
                         mechanic_signatures: [carlos, ana, supervisor].to_h { |employee| [employee.id.to_s, signature_strokes] })

      expect(form.save).to be(true)
      expect(maintenance_order.signatures.where(workshop_employee: supervisor).pluck(:signer_role_type))
        .to contain_exactly('supervisor', 'mechanic')
    end

    context 'when the order has no labor' do
      before { MaintenanceOrderLabor.delete_all }

      it 'asks the responsible employee to sign' do
        joao = create(:workshop_employee, tenant:, name: 'JOAO MENDES')
        maintenance_order.update!(responsible_employee: joao)
        form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: signature_strokes,
                           mechanic_signatures: { joao.id.to_s => signature_strokes })

        expect(form.save).to be(true)
        expect(maintenance_order.signatures.mechanic.pluck(:signer_name)).to eq(['JOAO MENDES'])
      end

      it 'does not finish an order without anyone to sign as mechanic' do
        form = finish_form(supervisor_id: supervisor.id.to_s, supervisor_signature: signature_strokes)

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Lance a mão de obra ou indique o funcionário responsável antes de encerrar a OS.'])
      end
    end
  end

  context 'when the signatures are not required' do
    it 'finishes the order without signatures' do
      create(:maintenance_order_labor, maintenance_order:)
      form = described_class.new(maintenance_order:, finished_at: '2026-11-11T17:30', release_test_type: 'road_test',
                                 performed_service: 'Troca')

      expect { expect(form.save).to be(true) }.not_to change(MaintenanceOrderSignature, :count)
      expect(maintenance_order.reload.status_type).to eq('finished')
    end
  end
end
