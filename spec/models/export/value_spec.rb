require 'rails_helper'

RSpec.describe Export::Value do
  describe '.cast' do
    it 'serializes each type the way the export service reads it' do
      values = {
        money: Money.from_cents(123_456), date: Time.zone.local(2026, 10, 2, 8, 30), datetime: Time.zone.local(2026, 10, 1, 16, 45),
        string: %w[EXU0F72 BEV4G50], integer: BigDecimal('12.6'), decimal: Money.from_cents(1_037), percentage: BigDecimal('20.7'), boolean: false
      }.to_h { |type, raw| [type, described_class.cast(type, raw)] }

      expect(values).to eq(
        money: 123_456, date: '2026-10-02', datetime: '2026-10-01T16:45:00-03:00', string: 'EXU0F72, BEV4G50', integer: 13,
        decimal: BigDecimal('10.37'), percentage: BigDecimal('20.7'), boolean: false
      )
    end

    it 'keeps money already in cents and turns a hash into text' do
      expect(described_class.cast(:money, 104_700_000)).to eq(104_700_000)
      expect(described_class.cast(:string, { 'a' => 1 })).to eq('{"a":1}')
    end

    it 'leaves a missing value empty in every type' do
      expect(%i[money date datetime string integer decimal percentage boolean].map { |type| described_class.cast(type, nil) }).to all(be_nil)
    end
  end
end
