require 'rails_helper'

RSpec.describe Customers::AssignCountryCommand do
  let!(:tenant) { create(:tenant) }

  context 'when foreign customers are registered with the city of the destination' do
    let!(:asuncion) { create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX') }
    let!(:assuncion) { create(:atua_customer, tenant:, name: 'FERROPAR S A', city: 'Assunción', state: 'EX') }
    let!(:buenos_aires) { create(:atua_customer, tenant:, name: 'FERROSIDER S/A', city: 'BUENOS AIRES', state: 'EX') }

    it 'assigns the country of the city' do
      expect(described_class.call(tenant)).to eq(3)

      expect(asuncion.reload.country_type).to eq('paraguay')
      expect(assuncion.reload.country_type).to eq('paraguay')
      expect(buenos_aires.reload.country_type).to eq('argentina')
    end
  end

  context 'when the city of a foreign customer is only EXTERIOR' do
    let!(:by_name) { create(:atua_customer, tenant:, name: 'GONVARRI ARGENTINA S.A.', city: 'EXTERIOR', state: 'EX') }
    let!(:by_street) do
      create(:atua_customer, tenant:, name: 'GALLO INDUSTRIA Y COMERCIO DE HIERROS S.', street: 'RUA D027 C/ ADAN RAMIREZ - CAPIATA, PARA, EXTERIOR',
                             city: 'EXTERIOR', state: 'EX')
    end
    let!(:unknown) do
      create(:atua_customer, tenant:, name: 'L ACERIE S A', street: 'AV BERNARDINO CABALLERO 1100 CASI TREBOL, EXTERIOR', city: 'EXTERIOR', state: 'EX')
    end

    it 'looks for the country in the name and in the address and leaves the unknown ones blank' do
      expect(described_class.call(tenant)).to eq(2)

      expect(by_name.reload.country_type).to eq('argentina')
      expect(by_street.reload.country_type).to eq('paraguay')
      expect(unknown.reload.country_type).to be_nil
    end
  end

  context 'when a Brazilian customer has a country name in its name' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'ARGENTINA COMERCIO LTDA', city: 'SAO PAULO', state: 'SP') }

    it 'leaves the country blank' do
      expect(described_class.call(tenant)).to eq(0)
      expect(customer.reload.country_type).to be_nil
    end
  end

  context 'when the customer moved from abroad to Brazil' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'FERROPAR S A', city: 'CASCAVEL', state: 'PR', country_type: 'paraguay') }

    it 'clears the country assigned before' do
      expect(described_class.call(tenant)).to eq(1)
      expect(customer.reload.country_type).to be_nil
    end
  end

  context 'when the country was changed by hand' do
    let!(:customer) do
      create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'other',
                             country_edited_at: Time.current)
    end

    it 'keeps the country changed by hand' do
      expect(described_class.call(tenant)).to eq(0)
      expect(customer.reload.country_type).to eq('other')
    end
  end

  context 'when the command runs again' do
    let!(:customer) { create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX') }

    it 'changes nothing the second time' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to(change { customer.reload.updated_at })
      expect(customer.country_type).to eq('paraguay')
    end
  end

  context 'when the customer belongs to another tenant' do
    let!(:other_customer) { create(:atua_customer, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX') }

    it 'does not change it' do
      expect(described_class.call(tenant)).to eq(0)
      expect(other_customer.reload.country_type).to be_nil
    end
  end
end
