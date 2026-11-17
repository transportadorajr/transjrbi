require 'rails_helper'

RSpec.describe MaintenancePartMovementForm do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant:) }
  let!(:part) { create(:maintenance_part, tenant:, quantity: 4) }
  let!(:supplier) { create(:supplier, tenant:) }

  before { travel_to(Time.zone.local(2026, 11, 17, 10)) }

  describe '#save' do
    it 'registers an entry' do
      form = described_class.new(tenant:, created_by: user, movement_type: 'entry', maintenance_part_id: part.id, moved_on: '2026-11-16',
                                 quantity: '2,5', unit_cost: '1.234,56', supplier_id: supplier.id, invoice_number: ' 4512 ')

      expect { expect(form.save).to be(true) }.to change(MaintenancePartMovement, :count).by(1)
      expect(MaintenancePartMovement.last).to have_attributes(movement_type: 'entry', quantity: 2.5, balance: 6.5, unit_cost_cents: 123_456,
                                                              supplier:, invoice_number: '4512', created_by: user)
    end

    it 'registers an adjustment with the difference to the counted quantity' do
      form = described_class.new(tenant:, movement_type: 'adjustment', maintenance_part_id: part.id, moved_on: '2026-11-17',
                                 quantity: '6', notes: 'Inventário', unit_cost: '10,00', supplier_id: supplier.id)

      expect(form.save).to be(true)
      expect(MaintenancePartMovement.last).to have_attributes(movement_type: 'adjustment', quantity: 2, balance: 6, unit_cost_cents: nil,
                                                              supplier: nil)
    end

    it 'accepts an adjustment counting zero' do
      form = described_class.new(tenant:, movement_type: 'adjustment', maintenance_part_id: part.id, moved_on: '2026-11-17',
                                 quantity: '0', notes: 'Perda')

      expect(form.save).to be(true)
      expect(part.reload.quantity).to eq(0)
    end

    it 'rejects an incomplete entry' do
      form = described_class.new(tenant:, movement_type: 'exit', moved_on: '2026-11-18', quantity: '0', unit_cost: 'abc')

      expect { expect(form.save).to be_falsey }.not_to change(MaintenancePartMovement, :count)
      expect(form.errors.full_messages).to contain_exactly('Peça não pode ficar em branco', 'Tipo não está incluído na lista',
                                                           'Data não pode ser no futuro', 'Quantidade deve ser maior que 0',
                                                           'Custo unitário não é um valor válido')
    end

    it 'rejects an inactive part and a supplier of another tenant' do
      inactive = create(:maintenance_part, tenant:, active: false)
      form = described_class.new(tenant:, movement_type: 'entry', maintenance_part_id: inactive.id, moved_on: '2026-11-17', quantity: '1',
                                 supplier_id: create(:supplier).id)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Peça não está cadastrada como peça ativa',
                                                           'Fornecedor não está cadastrado como fornecedor ativo')
    end

    it 'rejects an adjustment without notes or equal to the balance' do
      form = described_class.new(tenant:, movement_type: 'adjustment', maintenance_part_id: part.id, moved_on: '2026-11-17', quantity: '4')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Observação não pode ficar em branco', 'Quantidade é igual ao saldo atual da peça')
    end
  end
end
