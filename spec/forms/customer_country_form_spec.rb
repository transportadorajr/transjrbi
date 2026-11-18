require 'rails_helper'

RSpec.describe CustomerCountryForm do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'paraguay') }

  describe '.for_customer' do
    it 'leaves the country blank when it was not changed by hand' do
      expect(described_class.for_customer(customer).country_type).to be_nil
    end

    it 'fills the country changed by hand' do
      customer.update!(country_type: 'argentina', country_edited_at: Time.current)

      expect(described_class.for_customer(customer).country_type).to eq('argentina')
    end
  end

  describe '#save' do
    it 'saves the chosen country' do
      form = described_class.new(customer:, country_type: 'argentina')

      expect(form.save).to be(true)
      expect(customer.reload).to have_attributes(country_type: 'argentina', country_edited_at: be_present)
    end

    it 'goes back to the country identified automatically when the country is blank' do
      described_class.new(customer:, country_type: 'other').save

      expect(described_class.new(customer:, country_type: '').save).to be(true)
      expect(customer.reload).to have_attributes(country_type: 'paraguay', country_edited_at: nil)
    end

    it 'rejects an unknown country' do
      form = described_class.new(customer:, country_type: 'brazil')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['País não está incluído na lista'])
      expect(customer.reload.country_edited_at).to be_nil
    end
  end
end
