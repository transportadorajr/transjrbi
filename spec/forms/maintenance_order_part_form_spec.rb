require 'rails_helper'

RSpec.describe MaintenanceOrderPartForm do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:) }

  describe '#save' do
    it 'adds the part to the order and recalculates the totals' do
      form = described_class.new(maintenance_order:, code: ' lf-123 ', description: ' lona  de freio ', quantity: '2,5',
                                 unit: 'kg', source_type: 'purchase', document_number: ' NF 4512 ', unit_price: '1.234,56')

      expect { expect(form.save).to be(true) }.to change(MaintenanceOrderPart, :count).by(1)

      expect(MaintenanceOrderPart.last).to have_attributes(
        tenant:, maintenance_order:, code: 'LF-123', description: 'LONA DE FREIO', quantity: BigDecimal('2.5'), unit: 'KG',
        source_type: 'purchase', document_number: 'NF 4512', unit_price_cents: 123_456, total_cents: 308_640
      )
      expect(maintenance_order.reload).to have_attributes(parts_total_cents: 308_640, total_cents: 308_640)
    end

    it 'accepts a stock part without price' do
      form = described_class.new(maintenance_order:, description: 'Óleo 15W40', quantity: '30', unit: 'L')

      expect(form.save).to be(true)
      expect(MaintenanceOrderPart.last).to have_attributes(source_type: 'stock', unit_price_cents: 0, total_cents: 0)
    end

    it 'rejects a part without description and with a zero quantity or a bad price' do
      form = described_class.new(maintenance_order:, description: ' ', quantity: '0', source_type: 'loan', unit_price: 'abc')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenanceOrderPart, :count)
      expect(form.errors.full_messages).to contain_exactly('Descrição não pode ficar em branco', 'Quantidade deve ser maior que 0',
                                                           'Origem não está incluído na lista', 'Valor unitário não é um valor válido')
    end

    context 'when the part already exists' do
      let!(:part) { create(:maintenance_order_part, maintenance_order:, quantity: 4, unit_price_cents: 8_500, total_cents: 34_000) }

      it 'loads the values in the Brazilian format and updates the part' do
        form = described_class.for_item(part)

        expect(form).to have_attributes(quantity: '4', unit_price: '85,00', source_type: 'stock')

        form.assign_attributes(quantity: '6')

        expect { expect(form.save).to be(true) }.not_to change(MaintenanceOrderPart, :count)
        expect(part.reload).to have_attributes(quantity: 6, total_cents: 51_000)
        expect(maintenance_order.reload.total_cents).to eq(51_000)
      end
    end
  end
end
