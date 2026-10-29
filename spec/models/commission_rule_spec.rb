require 'rails_helper'

RSpec.describe CommissionRule do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }

  describe 'validations' do
    it 'requires a name and a percentage between zero and one hundred' do
      rule = described_class.new(tenant:, customer_group: usiminas, destination_type: 'national', base_type: 'freight',
                                 percentage: 100)

      expect(rule).not_to be_valid
      expect(rule.errors[:name]).to eq(['não pode ficar em branco'])
      expect(rule.errors[:percentage]).to eq(['deve ser menor que 100'])
    end

    it 'rejects an unknown destination' do
      rule = build(:commission_rule, tenant:, customer_group: usiminas, destination_type: 'moon')

      expect(rule).not_to be_valid
      expect(rule.errors[:destination_type]).to be_present
    end
  end

  describe '.for_destination' do
    let(:national) { build(:commission_rule, tenant:, customer_group: usiminas) }
    let(:argentina) { build(:commission_rule, :argentina, tenant:, customer_group: usiminas) }
    let(:paraguay) { build(:commission_rule, :paraguay, tenant:, customer_group: usiminas) }
    let(:rules) { [national, argentina, paraguay] }

    it 'uses the national rule for any brazilian state' do
      expect(described_class.for_destination(rules, 'MG', 'IPATINGA')).to eq(national)
      expect(described_class.for_destination(rules, 'MA', 'ROSARIO')).to eq(national)
    end

    it 'uses the foreign rule of the city when the state is EX, ignoring case, accents, spaces and hyphens' do
      expect(described_class.for_destination(rules, 'EX', 'ROSARIO')).to eq(argentina)
      expect(described_class.for_destination(rules, 'ex', 'PUERTO-IGUAZU')).to eq(argentina)
      expect(described_class.for_destination(rules, 'EX', 'asuncion')).to eq(paraguay)
      expect(described_class.for_destination(rules, 'EX', 'CIUDAD DEL ESTE')).to eq(paraguay)
    end

    it 'finds no rule for a foreign city outside every list' do
      expect(described_class.for_destination(rules, 'EX', 'SANTIAGO')).to be_nil
    end

    it 'uses the city of the recipient when the city of the CT-e is Exterior' do
      expect(described_class.for_destination(rules, 'EX', 'EXTERIOR', recipient_city: 'Ciudad del Este')).to eq(paraguay)
      expect(described_class.for_destination(rules, 'EX', nil, recipient_city: 'ROSARIO')).to eq(argentina)
    end

    it 'uses the name of the recipient when neither the CT-e nor the recipient has a city of the rules' do
      paraguayan = described_class.for_destination(rules, 'EX', 'EXTERIOR', recipient_city: 'EXTERIOR', recipient_name: 'Comercial Gallo S.A.')

      expect(paraguayan).to eq(paraguay)
      expect(described_class.for_destination(rules, 'EX', 'EXTERIOR', recipient_name: 'FERROSIDER SA')).to eq(argentina)
      expect(described_class.for_destination(rules, 'EX', 'EXTERIOR', recipient_name: 'ACME LTDA')).to be_nil
    end

    it 'prefers the city of the CT-e over the city and the name of the recipient' do
      expect(described_class.for_destination(rules, 'EX', 'ROSARIO', recipient_city: 'ASUNCION', recipient_name: 'GALLO')).to eq(argentina)
    end

    it 'ignores the recipient for a brazilian state' do
      expect(described_class.for_destination(rules, 'MG', 'IPATINGA', recipient_name: 'TERNIUM')).to eq(national)
    end
  end

  describe '#amount_cents' do
    it 'applies the percentage rounding half cents up' do
      rule = build(:commission_rule, percentage: BigDecimal('1.5'))

      expect(rule.amount_cents(100_001)).to eq(1_500)
      expect(rule.amount_cents(100_033)).to eq(1_500)
      expect(rule.amount_cents(100_034)).to eq(1_501)
    end
  end

  describe '#deducted_icms_cents' do
    it 'deducts the ICMS only when the base is the freight without ICMS' do
      expect(build(:commission_rule, base_type: 'freight_without_icms').deducted_icms_cents(9_000)).to eq(9_000)
      expect(build(:commission_rule, base_type: 'freight_without_icms').deducted_icms_cents(nil)).to eq(0)
      expect(build(:commission_rule, base_type: 'freight').deducted_icms_cents(9_000)).to eq(0)
    end
  end

  describe '.covered_documents' do
    let(:other_group) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS IPATINGA', customer_group: usiminas) }
    let!(:other_customer) { create(:atua_customer, tenant:, code: 502, customer_group: other_group) }
    let!(:rule) { create(:commission_rule, tenant:, customer_group: usiminas) }
    let!(:normal) { create(:atua_transport_document, tenant:, taker_code: 501) }
    let!(:ce) { create(:atua_transport_document, tenant:, taker_code: 501, document_kind: 'ce') }
    let!(:complement) { create(:atua_transport_document, tenant:, taker_code: 501, issue_kind: 'Complemento de Valores') }
    let!(:canceled) { create(:atua_transport_document, tenant:, taker_code: 501, canceled_at: Time.current) }
    let!(:removed) { create(:atua_transport_document, tenant:, taker_code: 501, removed_from_atua_at: Time.current) }
    let!(:sent_by_usiminas) { create(:atua_transport_document, tenant:, sender_code: 501, taker_code: 502) }

    it 'keeps only the normal CT-es taken by a customer of a group with an active rule' do
      expect(described_class.covered_documents(tenant)).to contain_exactly(normal)
    end

    it 'covers nothing when the rule is deactivated' do
      rule.update!(activated_at: nil)

      expect(described_class.covered_documents(tenant)).to be_empty
    end
  end
end
