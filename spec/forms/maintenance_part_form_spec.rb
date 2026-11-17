require 'rails_helper'

RSpec.describe MaintenancePartForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates the part normalizing the fields' do
      form = described_class.new(tenant:, code: ' lf-123 ', description: ' lona  de freio ', unit: 'un', brand: ' fras-le ',
                                 unit_price: '1.234,56')

      expect { expect(form.save).to be(true) }.to change(MaintenancePart, :count).by(1)

      expect(MaintenancePart.last).to have_attributes(tenant:, code: 'LF-123', description: 'LONA DE FREIO', unit: 'UN',
                                                      brand: 'FRAS-LE', unit_price_cents: 123_456, active: true)
    end

    it 'accepts a part without code nor price' do
      form = described_class.new(tenant:, description: 'Óleo 15W40', code: ' ', unit_price: '')

      expect(form.save).to be(true)
      expect(MaintenancePart.last).to have_attributes(code: nil, unit_price_cents: 0)
    end

    it 'rejects a part without description, with a bad price and an unknown unit' do
      form = described_class.new(tenant:, description: ' ', unit_price: 'abc', unit: 'saco')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenancePart, :count)
      expect(form.errors.full_messages).to contain_exactly('Descrição não pode ficar em branco', 'Valor unitário não é um valor válido',
                                                           'Unidade não está na lista de unidades')
    end

    it 'keeps offering the unit already saved on a part' do
      part = create(:maintenance_part, tenant:, unit: 'SACO')
      form = described_class.for_item(part)

      expect(form.units).to include('UN', 'SACO')
      expect(form.save).to be(true)
    end

    context 'when the tenant already has parts' do
      let!(:lining) { create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO') }
      let!(:stranger) { create(:maintenance_part, code: 'FO-200', description: 'FILTRO DE ÓLEO') }

      it 'rejects a code and a description already registered in the tenant' do
        form = described_class.new(tenant:, code: 'lf-123', description: 'lona de freio')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to contain_exactly('Código já está cadastrado em outra peça', 'Descrição já está cadastrada')
      end

      it 'accepts a code and a description registered in another tenant' do
        expect(described_class.new(tenant:, code: 'fo-200', description: 'filtro de óleo').save).to be(true)
      end

      it 'loads the values in the Brazilian format and updates the part keeping its own code' do
        lining.update!(unit_price_cents: 8_500, unit: 'UN')
        form = described_class.for_item(lining)

        expect(form).to have_attributes(code: 'LF-123', description: 'LONA DE FREIO', unit: 'UN', unit_price: '85,00', active: true)

        form.assign_attributes(unit_price: '90,00', active: false)

        expect { expect(form.save).to be(true) }.not_to change(MaintenancePart, :count)
        expect(lining.reload).to have_attributes(code: 'LF-123', unit_price_cents: 9_000, active: false)
      end
    end
  end
end
