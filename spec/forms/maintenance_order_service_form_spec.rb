require 'rails_helper'

RSpec.describe MaintenanceOrderServiceForm do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:) }
  let!(:supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }
  let!(:part) { create(:maintenance_order_part, maintenance_order:, total_cents: 10_000) }

  describe '#save' do
    it 'adds the service to the order and recalculates the totals with the approved value' do
      form = described_class.new(maintenance_order:, supplier_id: supplier.id, description: ' Retífica do tambor ', quote_number: ' 77 ',
                                 quoted: '450,00', approved: '420,00', approved_by_name: ' marcos ', invoice_number: '9981')

      expect { expect(form.save).to be(true) }.to change(MaintenanceOrderService, :count).by(1)

      expect(MaintenanceOrderService.last).to have_attributes(
        tenant:, maintenance_order:, supplier:, description: 'Retífica do tambor', quote_number: '77', quoted_cents: 45_000,
        approved_cents: 42_000, approved_by_name: 'MARCOS', invoice_number: '9981'
      )
      expect(maintenance_order.reload).to have_attributes(parts_total_cents: 10_000, services_total_cents: 42_000, total_cents: 52_000)
    end

    it 'uses the quoted value while the service is not approved' do
      form = described_class.new(maintenance_order:, supplier_id: supplier.id, description: 'Alinhamento', quoted: '180,00')

      expect(form.save).to be(true)
      expect(MaintenanceOrderService.last.approved_cents).to be_nil
      expect(maintenance_order.reload.services_total_cents).to eq(18_000)
    end

    it 'rejects a service without supplier and description or with bad values' do
      form = described_class.new(maintenance_order:, description: ' ', quoted: 'x', approved: '-')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrderService, :count)
      expect(form.errors.full_messages).to contain_exactly('Fornecedor não pode ficar em branco', 'Serviço não pode ficar em branco',
                                                           'Valor orçado não é um valor válido', 'Valor aprovado não é um valor válido')
    end

    it 'rejects an inactive supplier or one of another tenant' do
      [create(:supplier, tenant:, active: false), create(:supplier)].each do |other|
        form = described_class.new(maintenance_order:, supplier_id: other.id, description: 'Alinhamento')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Fornecedor não está cadastrado como fornecedor ativo'])
      end
    end

    context 'when the service already exists' do
      let!(:service) { create(:maintenance_order_service, maintenance_order:, supplier:, quoted_cents: 45_000, approved_cents: nil) }

      it 'loads the values in the Brazilian format and records the approval' do
        form = described_class.for_item(service)

        expect(form).to have_attributes(quoted: '450,00', approved: nil)

        form.assign_attributes(approved: '400,00', approved_by_name: 'Marcos')

        expect(form.save).to be(true)
        expect(service.reload).to have_attributes(approved_cents: 40_000, approved_by_name: 'MARCOS')
        expect(maintenance_order.reload.total_cents).to eq(50_000)
      end
    end
  end
end
