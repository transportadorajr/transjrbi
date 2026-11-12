require 'rails_helper'

RSpec.describe TonnageRateForm do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }

  describe '.new' do
    it 'starts with the Brasiltec name and the USIMINAS group' do
      usiminas

      form = described_class.new(tenant:)

      expect(form).to have_attributes(name: 'Brasiltec', customer_group_id: usiminas.id)
      expect(form).to be_default_fields_locked
    end

    it 'keeps the name and the group the user sent' do
      usiminas
      gerdau = create(:customer_group, tenant:, name: 'GERDAU')

      form = described_class.new(tenant:, name: 'Outro custo', customer_group_id: gerdau.id)

      expect(form).to have_attributes(name: 'Outro custo', customer_group_id: gerdau.id)
    end
  end

  describe '#save' do
    it 'creates an active rate and recalculates the freight expenses' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: ' Brasiltec ', origin: 'Utinga',
                                 valid_month: '2026-10', rate: '18,02', active: '1')

      expect { expect(form.save).to be(true) }.to change(TonnageRate, :count).by(1)
        .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

      rate = TonnageRate.last
      expect(rate).to have_attributes(tenant:, customer_group: usiminas, name: 'Brasiltec', nickname: 'Utinga', origin_city: 'Santo André',
                                      origin_state: 'SP', valid_month: Date.new(2026, 10, 1), rate_cents: 1_802)
      expect(rate.activated_at).to be_present
    end

    it 'accepts a rate with thousands separator' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin: 'Cubatão',
                                 valid_month: '2026-10', rate: '1.012,5')

      expect(form.save).to be(true)
      expect(TonnageRate.last.rate_cents).to eq(101_250)
    end

    it 'rejects a rate without the required fields' do
      form = described_class.new(tenant:, customer_group_id: '', name: '', valid_month: 'outubro', rate: 'doze')

      expect { expect(form.save).to be_falsey }.not_to change(TonnageRate, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Grupo de clientes não pode ficar em branco', 'Nome não pode ficar em branco', 'Origem não pode ficar em branco',
        'Vigência não é um mês válido', 'Valor por tonelada deve ser maior que 0'
      )
      expect(form).not_to be_default_fields_locked
    end

    it 'rejects an origin out of the list' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin: 'Santa Luiza',
                                 valid_month: '2026-10', rate: '9')

      expect { expect(form.save).to be_falsey }.not_to change(TonnageRate, :count)
      expect(form.errors[:origin]).to eq(['não está na lista de origens'])
    end

    it 'creates the TISL rate in Santa Luzia/MG' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin: 'TISL',
                                 valid_month: '2026-11', rate: '9,50')

      expect(form.save).to be(true)
      expect(TonnageRate.last).to have_attributes(nickname: 'TISL', origin_city: 'Santa Luzia', origin_state: 'MG', rate_cents: 950)
    end

    it 'rejects a customer group of another tenant' do
      stranger_group = create(:customer_group, tenant: create(:tenant))
      form = described_class.new(tenant:, customer_group_id: stranger_group.id, name: 'Brasiltec', origin: 'Cubatão',
                                 valid_month: '2026-10', rate: '12,57')

      expect(form.save).to be_falsey
      expect(form.errors[:customer_group_id]).to eq(['não pertence a esta empresa'])
    end

    context 'when the origin already has an active rate in the month' do
      let!(:cubatao) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

      it 'rejects the same origin in the same month' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Outro', origin: 'Cubatão',
                                   valid_month: '2026-10', rate: '13')

        expect(form.save).to be_falsey
        expect(form.errors[:origin]).to eq(['já tem outro custo ativo deste grupo nesta vigência'])
      end

      it 'accepts the same origin in the next month' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Brasiltec', origin: 'Cubatão',
                                   valid_month: '2026-11', rate: '13')

        expect(form.save).to be(true)
      end

      it 'updates the rate without colliding with itself' do
        form = described_class.for_tonnage_rate(cubatao)
        form.assign_attributes(rate: '12,80')

        expect(form.save).to be(true)
        expect(cubatao.reload.rate_cents).to eq(1_280)
      end

      it 'marks a copied rate as reviewed when it is saved' do
        copy = create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 11, 1), copied_from: cubatao)
        form = described_class.for_tonnage_rate(copy)
        form.assign_attributes(rate: '13,10')

        expect(form.save).to be(true)
        expect(copy.reload).to have_attributes(rate_cents: 1_310, copied_from_id: nil)
        expect(copy).not_to be_pending_review
      end

      it 'loads the rate formatted for the form' do
        form = described_class.for_tonnage_rate(cubatao)

        expect(form).to have_attributes(valid_month: '2026-10', rate: '12,57', origin: 'Cubatão', active: true)
      end

      it 'keeps an origin out of the list available when editing' do
        legacy = create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: nil, origin_city: 'Betim', origin_state: 'MG')
        form = described_class.for_tonnage_rate(legacy)
        form.assign_attributes(rate: '7')

        expect(form.origins.map(&:key)).to include('Betim/MG')
        expect(form.save).to be(true)
        expect(legacy.reload).to have_attributes(nickname: nil, origin_city: 'Betim', origin_state: 'MG', rate_cents: 700)
      end
    end
  end
end
