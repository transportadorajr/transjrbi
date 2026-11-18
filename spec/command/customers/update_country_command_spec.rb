require 'rails_helper'

RSpec.describe Customers::UpdateCountryCommand do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:atua_customer, tenant:, name: 'FERROSIDER S/A', city: 'EXTERIOR', state: 'EX') }

  context 'when a country is given' do
    it 'keeps the country and stamps the change by hand' do
      described_class.call(customer, 'argentina')

      expect(customer.reload.country_type).to eq('argentina')
      expect(customer.country_edited_at).to be_present
    end

    it 'does not stamp the change again when the country is the same' do
      described_class.call(customer, 'argentina')

      expect { described_class.call(customer, 'argentina') }.not_to(change { customer.reload.country_edited_at })
    end
  end

  context 'when the country is cleared' do
    let!(:customer) do
      create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'other',
                             country_edited_at: Time.current)
    end

    it 'goes back to the country identified by the city' do
      described_class.call(customer, '')

      expect(customer.reload.country_type).to eq('paraguay')
      expect(customer.country_edited_at).to be_nil
    end
  end
end
