require 'rails_helper'

RSpec.describe SupplierForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates an active supplier of the tenant' do
      form = described_class.new(tenant:, name: ' Retífica  Ipatinga ', document: '12.345.678/0001-90')

      expect { expect(form.save).to be(true) }.to change(Supplier, :count).by(1)

      expect(Supplier.last).to have_attributes(tenant:, name: 'RETÍFICA IPATINGA', document: '12.345.678/0001-90', active: true)
    end

    it 'accepts a supplier without document' do
      form = described_class.new(tenant:, name: 'Borracharia Central', document: ' ')

      expect(form.save).to be(true)
      expect(Supplier.last.document).to be_nil
    end

    it 'rejects a supplier without name or with a document of the wrong size' do
      form = described_class.new(tenant:, name: ' ', document: '123.456')

      expect { expect(form.save).to be_falsey }.not_to change(Supplier, :count)
      expect(form.errors.full_messages).to contain_exactly('Nome não pode ficar em branco',
                                                           'CNPJ / CPF deve ter 11 dígitos (CPF) ou 14 dígitos (CNPJ)')
    end

    context 'when the name is already registered' do
      let!(:supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }

      it 'rejects another supplier with the same name' do
        form = described_class.new(tenant:, name: 'retífica ipatinga')

        expect { expect(form.save).to be_falsey }.not_to change(Supplier, :count)
        expect(form.errors.full_messages).to eq(['Nome já está cadastrado'])
      end

      it 'updates the supplier keeping its own name' do
        form = described_class.for_supplier(supplier)
        form.assign_attributes(document: '123.456.789-09', active: false)

        expect { expect(form.save).to be(true) }.not_to change(Supplier, :count)
        expect(supplier.reload).to have_attributes(name: 'RETÍFICA IPATINGA', document: '123.456.789-09', active: false)
      end
    end
  end
end
