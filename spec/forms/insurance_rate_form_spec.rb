require 'rails_helper'

RSpec.describe InsuranceRateForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates a rate and recalculates the freight expenses' do
      form = described_class.new(tenant:, valid_from: '2026-10-01', insurance_percentage: '0,022', iof_percentage: '7,38')

      expect { expect(form.save).to be(true) }.to change(InsuranceRate, :count).by(1)
        .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

      expect(InsuranceRate.last).to have_attributes(tenant:, valid_from: Date.new(2026, 10, 1), insurance_percentage: BigDecimal('0.022'),
                                                    iof_percentage: BigDecimal('7.38'))
    end

    it 'accepts the percentages with a dot as decimal separator' do
      form = described_class.new(tenant:, valid_from: '2026-10-01', insurance_percentage: '0.03', iof_percentage: '0')

      expect(form.save).to be(true)
      expect(InsuranceRate.last).to have_attributes(insurance_percentage: BigDecimal('0.03'), iof_percentage: BigDecimal('0'))
    end

    it 'rejects a rate without the required fields' do
      form = described_class.new(tenant:, insurance_percentage: 'zero', iof_percentage: '100')

      expect { expect(form.save).to be_falsey }.not_to change(InsuranceRate, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Início da vigência não pode ficar em branco', 'Alíquota do seguro (%) deve ser maior que 0 e menor que 100',
        'Alíquota do IOF (%) deve ser maior ou igual a 0 e menor que 100'
      )
    end

    context 'when the tenant already has a rate on the date' do
      let!(:rate) { create(:insurance_rate, tenant:) }

      it 'rejects another rate starting on the same day' do
        form = described_class.new(tenant:, valid_from: '2026-10-01', insurance_percentage: '0,03', iof_percentage: '7,38')

        expect(form.save).to be_falsey
        expect(form.errors[:valid_from]).to eq(['já tem outra alíquota cadastrada nesta data'])
      end

      it 'updates the rate keeping its date' do
        form = described_class.for_insurance_rate(rate)
        form.assign_attributes(insurance_percentage: '0,025')

        expect { expect(form.save).to be(true) }.to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)
        expect(rate.reload.insurance_percentage).to eq(BigDecimal('0.025'))
      end

      it 'accepts the same day in another tenant' do
        form = described_class.new(tenant: create(:tenant), valid_from: '2026-10-01', insurance_percentage: '0,022', iof_percentage: '7,38')

        expect(form.save).to be(true)
      end
    end
  end

  describe '.for_insurance_rate' do
    it 'fills the form with the percentages formatted with comma' do
      form = described_class.for_insurance_rate(create(:insurance_rate, tenant:))

      expect(form).to have_attributes(valid_from: Date.new(2026, 10, 1), insurance_percentage: '0,022', iof_percentage: '7,38')
      expect(form).to be_persisted
    end
  end
end
