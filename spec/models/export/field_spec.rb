require 'rails_helper'

RSpec.describe Export::Field do
  let!(:tenant) { create(:tenant) }

  describe '.computed' do
    it 'reads the value through the block and serializes it by its type' do
      field = described_class.computed('Lançado em', :date) { |row| row[:posted_at] }

      expect(field.to_h).to eq(header: 'Lançado em', type: :date)
      expect(field.value({ posted_at: Time.zone.local(2026, 10, 2, 8, 30) })).to eq('2026-10-02')
      expect(field).to be_translated
    end
  end

  describe '.for' do
    let!(:customer_group) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:city) { create(:city, tenant:, name: 'Ipatinga') }

    it 'names the field after the attribute of the model and reads the method of the same name by default' do
      field = described_class.for(CustomerGroup, :name)

      expect(field.to_h).to eq(header: 'Nome', type: :string)
      expect(field.value(customer_group)).to eq('USIMINAS')
    end

    it 'tells whether the header comes from the locale files' do
      expect(described_class.for(City, :macro_region)).to be_translated
      expect(described_class.for(City, :unknown_attribute)).not_to be_translated
    end

    it 'formats money with the currency of the locale' do
      expect(described_class.for(ExcludedIssuer, :freight, :money).to_h).to eq(header: 'Frete bruto', type: :money, format: '"R$" #,##0.00')
      expect(described_class.for(ExcludedIssuer, :freight, :money) { 1_047_000 }.value(city)).to eq(1_047_000)
    end
  end
end
