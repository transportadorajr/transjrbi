require 'rails_helper'

RSpec.describe MaintenanceOrderPostingForm do
  let(:tenant) { create(:tenant) }
  let(:office) { create(:user, tenant:, name: 'ANA ESCRITÓRIO') }
  let!(:maintenance_order) do
    create(:maintenance_order, tenant:, number: 7, status_type: 'finished', finished_at: Time.zone.local(2026, 11, 11, 17, 30))
  end

  before { travel_to(Time.zone.local(2026, 11, 12, 9)) }

  describe '.for_maintenance_order' do
    it 'suggests today for an order not posted yet' do
      form = described_class.for_maintenance_order(maintenance_order)

      expect(form).to have_attributes(atua_order_number: nil, posted_on: Date.new(2026, 11, 12), posting_verified: false)
    end

    it 'keeps the posting already saved' do
      maintenance_order.update!(atua_order_number: '4521', posted_on: Date.new(2026, 11, 11), posting_verified: true)

      form = described_class.for_maintenance_order(maintenance_order)

      expect(form).to have_attributes(atua_order_number: '4521', posted_on: Date.new(2026, 11, 11), posting_verified: true)
    end
  end

  describe '#save' do
    it 'posts the order with the user who posted it' do
      form = described_class.new(maintenance_order:, posted_by: office, atua_order_number: ' 4521 ', posted_on: '2026-11-12',
                                 posting_verified: '1')

      expect(form.save).to be(true)
      expect(maintenance_order.reload).to have_attributes(atua_order_number: '4521', posted_on: Date.new(2026, 11, 12),
                                                          posted_by: office, posting_verified: true)
    end

    it 'keeps who posted the order when another user only verifies it' do
      maintenance_order.update!(atua_order_number: '4521', posted_on: Date.new(2026, 11, 12), posted_by: office)
      checker = create(:user, tenant:, name: 'BRUNO CONFERENTE')
      form = described_class.new(maintenance_order:, posted_by: checker, atua_order_number: '4521', posted_on: '2026-11-12',
                                 posting_verified: '1')

      expect(form.save).to be(true)
      expect(maintenance_order.reload).to have_attributes(posted_by: office, posting_verified: true)
    end

    it 'rejects a posting without the Atua number and the date' do
      form = described_class.new(maintenance_order:, posted_by: office, atua_order_number: ' ', posted_on: '')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('Nº OS Atua não pode ficar em branco', 'Lançada em não pode ficar em branco')
      expect(maintenance_order.reload.posted_on).to be_nil
    end

    it 'rejects a date before the conclusion or in the future' do
      before_conclusion = described_class.new(maintenance_order:, posted_by: office, atua_order_number: '4521', posted_on: '2026-11-10')
      future = described_class.new(maintenance_order:, posted_by: office, atua_order_number: '4521', posted_on: '2026-11-13')

      expect(before_conclusion.save).to be_falsey
      expect(before_conclusion.errors.full_messages).to eq(['Lançada em não pode ser antes da conclusão da OS'])
      expect(future.save).to be_falsey
      expect(future.errors.full_messages).to eq(['Lançada em não pode ser uma data futura'])
    end

    it 'rejects an Atua number already posted on another order of the tenant' do
      create(:maintenance_order, tenant:, number: 5, status_type: 'finished', atua_order_number: '4521')
      create(:maintenance_order, tenant: create(:tenant), number: 6, atua_order_number: '9999')
      form = described_class.new(maintenance_order:, posted_by: office, atua_order_number: '4521', posted_on: '2026-11-12')
      stranger_number = described_class.new(maintenance_order:, posted_by: office, atua_order_number: '9999', posted_on: '2026-11-12')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Nº OS Atua já foi lançado na OS 5'])
      expect(stranger_number.save).to be(true)
    end

    it 'does not post an order that is not finished' do
      maintenance_order.update!(status_type: 'cancelled')
      form = described_class.new(maintenance_order:, posted_by: office, atua_order_number: '4521', posted_on: '2026-11-12')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Só uma OS concluída pode ser lançada no Atua, e esta está cancelada.'])
      expect(maintenance_order.reload.atua_order_number).to be_nil
    end
  end
end
