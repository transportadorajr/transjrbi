require 'rails_helper'

RSpec.describe TonnageRateForm do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }

  describe '#save' do
    it 'creates an active rate and recalculates the freight expenses' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: ' Brasiltec ', nickname: ' Utinga ',
                                 origin_city: ' Santo  André ', origin_state: 'sp', valid_month: '2026-10', rate: '18,02', active: '1')

      expect { expect(form.save).to be(true) }.to change(TonnageRate, :count).by(1)
        .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

      rate = TonnageRate.last
      expect(rate).to have_attributes(tenant:, customer_group: usiminas, name: 'Brasiltec', nickname: 'Utinga', origin_city: 'Santo André',
                                      origin_state: 'SP', valid_month: Date.new(2026, 10, 1), rate_cents: 1_802)
      expect(rate.activated_at).to be_present
    end

    it 'accepts a rate with thousands separator' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin_city: 'Cubatão', origin_state: 'SP',
                                 valid_month: '2026-10', rate: '1.012,5')

      expect(form.save).to be(true)
      expect(TonnageRate.last.rate_cents).to eq(101_250)
    end

    it 'rejects a rate without the required fields' do
      form = described_class.new(tenant:, valid_month: 'outubro', rate: 'doze', origin_state: 'São Paulo')

      expect { expect(form.save).to be_falsey }.not_to change(TonnageRate, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Grupo de clientes não pode ficar em branco', 'Nome não pode ficar em branco', 'Cidade de origem não pode ficar em branco',
        'UF de origem não é válido', 'Vigência não é um mês válido', 'Valor por tonelada (R$) deve ser maior que 0'
      )
    end

    it 'rejects a customer group of another tenant' do
      stranger_group = create(:customer_group, tenant: create(:tenant))
      form = described_class.new(tenant:, customer_group_id: stranger_group.id, name: 'Brasiltec', origin_city: 'Cubatão',
                                 origin_state: 'SP', valid_month: '2026-10', rate: '12,57')

      expect(form.save).to be_falsey
      expect(form.errors[:customer_group_id]).to eq(['não pertence a esta empresa'])
    end

    context 'when the origin already has an active rate in the month' do
      let!(:cubatao) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

      it 'rejects the same origin written in another way' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Outro', origin_city: 'CUBATAO', origin_state: 'sp',
                                   valid_month: '2026-10', rate: '13')

        expect(form.save).to be_falsey
        expect(form.errors[:origin_city]).to eq(['já tem outro custo ativo deste grupo nesta vigência'])
      end

      it 'accepts the same origin in the next month' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin_city: 'Cubatão', origin_state: 'SP',
                                   valid_month: '2026-11', rate: '13')

        expect(form.save).to be(true)
      end

      it 'updates the rate without colliding with itself' do
        form = described_class.for_tonnage_rate(cubatao)
        form.assign_attributes(rate: '12,80')

        expect(form.save).to be(true)
        expect(cubatao.reload.rate_cents).to eq(1_280)
      end

      it 'loads the rate formatted for the form' do
        form = described_class.for_tonnage_rate(cubatao)

        expect(form).to have_attributes(valid_month: '2026-10', rate: '12,57', origin_city: 'Cubatão', origin_state: 'SP', active: true)
      end
    end
  end
end
