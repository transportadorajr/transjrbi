require 'rails_helper'

RSpec.describe DistanceAdjustment do
  let!(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the number and a positive distance' do
      adjustment = described_class.new(tenant:, transport_document_number: '', distance_km: 0)

      expect(adjustment).not_to be_valid
      expect(adjustment.errors.full_messages).to eq(['Número do CT-e não pode ficar em branco', 'KM considerado deve ser maior que 0'])
    end

    it 'accepts one adjustment per number in the tenant' do
      create(:distance_adjustment, tenant:, transport_document_number: '74120')
      other_tenant = create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra')

      expect(build(:distance_adjustment, tenant:, transport_document_number: '74120')).not_to be_valid
      expect(build(:distance_adjustment, tenant: other_tenant, transport_document_number: '74120')).to be_valid
    end
  end

  describe 'scopes' do
    let!(:applied) { create(:distance_adjustment, tenant:, transport_document_number: '74120', applied_at: 1.day.ago) }
    let!(:pending) { create(:distance_adjustment, tenant:, transport_document_number: '75300') }

    it 'filters by status' do
      expect(described_class.by_status('applied')).to eq([applied])
      expect(described_class.by_status('pending')).to eq([pending])
    end

    it 'filters by part of the number' do
      expect(described_class.by_number('753')).to eq([pending])
    end
  end

  describe '.normalize_number' do
    it 'drops the decimals of spreadsheet numbers and the leading zeros' do
      expect(described_class.normalize_number(74_120.0)).to eq('74120')
      expect(described_class.normalize_number(' 0074120 ')).to eq('74120')
      expect(described_class.normalize_number('0')).to eq('0')
    end
  end

  describe '#transport_documents' do
    it 'returns the documents of the tenant with the number' do
      adjustment = create(:distance_adjustment, tenant:, transport_document_number: '74120')
      document = create(:atua_transport_document, tenant:, number: '74120')
      create(:atua_transport_document, tenant:, number: '74121')
      create(:atua_transport_document, tenant: create(:tenant, name: 'Outra', trade_name: 'Outra'), number: '74120')

      expect(adjustment.transport_documents).to eq([document])
    end
  end
end
