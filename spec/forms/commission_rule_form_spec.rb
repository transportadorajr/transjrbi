require 'rails_helper'

RSpec.describe CommissionRuleForm do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }

  describe '#save' do
    it 'creates an active foreign rule with one city per line and recalculates the commissions' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: ' Argentina ', destination_type: 'foreign',
                                 base_type: 'freight', percentage: '1,3', cities: "Buenos Aires\n rosario \n\nROSÁRIO", active: '1')

      expect { expect(form.save).to be(true) }.to change(CommissionRule, :count).by(1)
        .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

      rule = CommissionRule.last
      expect(rule).to have_attributes(tenant:, customer_group: usiminas, name: 'Argentina', destination_type: 'foreign',
                                      base_type: 'freight', percentage: BigDecimal('1.3'), cities: ['Buenos Aires', 'rosario'])
      expect(rule.activated_at).to be_present
    end

    it 'ignores the cities of a national rule' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Nacional', destination_type: 'national',
                                 base_type: 'freight_without_icms', percentage: '2', cities: 'Ipatinga')

      expect(form.save).to be(true)
      expect(CommissionRule.last.cities).to eq([])
    end

    it 'rejects a rule without the required fields' do
      form = described_class.new(tenant:, percentage: 'dois')

      expect { expect(form.save).to be_falsey }.not_to change(CommissionRule, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Grupo de clientes não pode ficar em branco', 'Nome não pode ficar em branco', 'Destino não pode ficar em branco',
        'Base de cálculo não pode ficar em branco', 'Comissão (%) deve ser maior que 0 e menor que 100'
      )
    end

    it 'rejects a foreign rule without cities' do
      form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Paraguai', destination_type: 'foreign',
                                 base_type: 'freight', percentage: '1,5', cities: " \n ")

      expect(form.save).to be_falsey
      expect(form.errors[:cities]).to eq(['não pode ficar em branco'])
    end

    it 'rejects a customer group of another tenant' do
      stranger_group = create(:customer_group, tenant: create(:tenant))
      form = described_class.new(tenant:, customer_group_id: stranger_group.id, name: 'Nacional', destination_type: 'national',
                                 base_type: 'freight', percentage: '2')

      expect(form.save).to be_falsey
      expect(form.errors[:customer_group_id]).to eq(['não pertence a esta empresa'])
    end

    context 'when the group already has active rules' do
      let!(:national) { create(:commission_rule, tenant:, customer_group: usiminas) }
      let!(:argentina) { create(:commission_rule, :argentina, tenant:, customer_group: usiminas) }

      it 'rejects a second active national rule' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Nacional 2', destination_type: 'national',
                                   base_type: 'freight', percentage: '3')

        expect(form.save).to be_falsey
        expect(form.errors[:destination_type]).to eq(['nacional já tem outra regra ativa neste grupo'])
      end

      it 'rejects a city that is already in another active foreign rule' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Paraguai', destination_type: 'foreign',
                                   base_type: 'freight', percentage: '1,5', cities: "Asunción\nPUERTO IGUAZU")

        expect(form.save).to be_falsey
        expect(form.errors[:cities]).to eq(['PUERTO IGUAZU já estão em outra regra ativa deste grupo'])
      end

      it 'accepts the same national rule when the new one is inactive' do
        form = described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Nacional antiga', destination_type: 'national',
                                   base_type: 'freight', percentage: '3', active: '0')

        expect(form.save).to be(true)
      end

      it 'updates the percentage of the existing rule without colliding with itself' do
        form = described_class.for_commission_rule(national)
        form.assign_attributes(percentage: '2,5')

        expect(form.percentage).to eq('2,5')
        expect(form.save).to be(true)
        expect(national.reload.percentage).to eq(BigDecimal('2.5'))
      end

      it 'loads the rule formatted for the form' do
        form = described_class.for_commission_rule(argentina)

        expect(form).to have_attributes(percentage: '1,3', cities: "Buenos Aires\nPuerto Iguazú\nRosario", active: true)
      end
    end
  end
end
