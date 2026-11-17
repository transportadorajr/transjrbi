require 'rails_helper'

RSpec.describe MaintenanceServiceForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates the service normalizing the fields' do
      form = described_class.new(tenant:, code: ' ret-01 ', description: ' retífica  de motor ', price: '8.500,00')

      expect { expect(form.save).to be(true) }.to change(MaintenanceService, :count).by(1)

      expect(MaintenanceService.last).to have_attributes(tenant:, code: 'RET-01', description: 'RETÍFICA DE MOTOR', price_cents: 850_000,
                                                         active: true)
    end

    it 'rejects a service without description and with a bad price' do
      form = described_class.new(tenant:, description: '', price: '-10,00')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceService, :count)
      expect(form.errors.full_messages).to contain_exactly('Descrição não pode ficar em branco', 'Valor de referência não é um valor válido')
    end

    context 'when the service already exists' do
      let!(:grinding) { create(:maintenance_service, tenant:, code: 'RET-01', description: 'RETÍFICA DE MOTOR', price_cents: 850_000) }

      it 'rejects a code already registered in another service' do
        form = described_class.new(tenant:, code: 'ret-01', description: 'Solda')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to contain_exactly('Código já está cadastrado em outro serviço')
      end

      it 'updates the service' do
        form = described_class.for_item(grinding)

        expect(form).to have_attributes(price: '8.500,00')

        form.assign_attributes(description: 'retífica completa de motor')

        expect(form.save).to be(true)
        expect(grinding.reload).to have_attributes(description: 'RETÍFICA COMPLETA DE MOTOR', price_cents: 850_000)
      end
    end
  end
end
