require 'rails_helper'

RSpec.describe InsuranceRateForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    context 'when the tenant has no rate' do
      it 'creates the rate and recalculates the freight expenses' do
        form = described_class.for_tenant(tenant)
        form.assign_attributes(insurance_percentage: '0,03', iof_percentage: '6,38')

        expect { expect(form.save).to be(true) }.to change(InsuranceRate, :count).by(1)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(InsuranceRate.last).to have_attributes(tenant:, insurance_percentage: BigDecimal('0.03'), iof_percentage: BigDecimal('6.38'))
      end
    end

    context 'when the tenant already has a rate' do
      let!(:rate) { create(:insurance_rate, tenant:) }

      it 'updates the rate and recalculates the freight expenses' do
        form = described_class.for_tenant(tenant)
        form.assign_attributes(insurance_percentage: '0,025')

        expect { expect(form.save).to be(true) }.to not_change(InsuranceRate, :count)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(rate.reload).to have_attributes(insurance_percentage: BigDecimal('0.025'), iof_percentage: BigDecimal('7.38'))
      end

      it 'accepts the percentages with a dot as decimal separator' do
        form = described_class.for_tenant(tenant)
        form.assign_attributes(insurance_percentage: '0.03', iof_percentage: '0')

        expect(form.save).to be(true)
        expect(rate.reload).to have_attributes(insurance_percentage: BigDecimal('0.03'), iof_percentage: BigDecimal('0'))
      end

      it 'rejects percentages out of range' do
        form = described_class.for_tenant(tenant)
        form.assign_attributes(insurance_percentage: 'zero', iof_percentage: '100')

        expect { expect(form.save).to be_falsey }.not_to have_enqueued_job(FreightExpenses::CalculateJob)
        expect(form.errors.full_messages).to contain_exactly(
          'Alíquota do seguro (%) deve ser maior que 0 e menor que 100', 'Alíquota do IOF (%) deve ser maior ou igual a 0 e menor que 100'
        )
        expect(rate.reload.insurance_percentage).to eq(BigDecimal('0.022'))
      end
    end
  end

  describe '.for_tenant' do
    it 'fills the form with the percentages of the rate formatted with comma' do
      create(:insurance_rate, tenant:, insurance_percentage: BigDecimal('0.025'), iof_percentage: BigDecimal('6.38'))

      form = described_class.for_tenant(tenant)

      expect(form).to have_attributes(insurance_percentage: '0,025', iof_percentage: '6,38')
      expect(form).to be_persisted
    end

    it 'suggests the default percentages when the tenant has no rate' do
      form = described_class.for_tenant(tenant)

      expect(form).to have_attributes(insurance_percentage: '0,022', iof_percentage: '7,38')
      expect(form).not_to be_persisted
    end
  end
end
