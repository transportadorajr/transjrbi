require 'rails_helper'

RSpec.describe EmergencyContactForm do
  let(:tenant) { create(:tenant) }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA') }

  describe '.for_employee' do
    it 'suggests the next priority of the employee' do
      create(:emergency_contact, employee: jose, position: 1)

      expect(described_class.for_employee(jose).position).to eq(2)
    end
  end

  describe '#save' do
    it 'creates the emergency contact of the employee with the phones as digits' do
      form = described_class.new(employee: jose, name: '  Maria   da Silva ', relationship_type: 'spouse', phone: '(45) 99984-8077',
                                 secondary_phone: '+54 9 3772 57-3358', position: 1, notes: '  ligar  à noite ')

      expect { expect(form.save).to be(true) }.to change(EmergencyContact, :count).by(1)

      expect(EmergencyContact.last).to have_attributes(tenant:, employee: jose, name: 'Maria da Silva', relationship_type: 'spouse',
                                                       phone: '45999848077', secondary_phone: '+5493772573358', position: 1, notes: 'ligar à noite')
    end

    it 'requires the name and the phone' do
      form = described_class.new(employee: jose, position: 1)

      expect { expect(form.save).to be_falsey }.not_to change(EmergencyContact, :count)
      expect(form.errors.full_messages).to eq(['Nome do contato não pode ficar em branco', 'Telefone não pode ficar em branco'])
    end

    it 'rejects phones with digits missing or left over' do
      form = described_class.new(employee: jose, name: 'Maria', phone: '(45)9.99848-0771', secondary_phone: '9984-8077', position: 1)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Telefone deve ter o DDD e o número, ou o código do país antes', 'Outro telefone deve ter o DDD e o número, ou o código do país antes'])
    end

    it 'updates an emergency contact' do
      emergency_contact = create(:emergency_contact, employee: jose, name: 'Maria', relationship_type: 'spouse', phone: '45999848077')
      form = described_class.for_emergency_contact(emergency_contact)
      form.assign_attributes(name: 'Maria Souza', relationship_type: 'mother', phone: '(45) 3254-1000', position: '2')

      expect { expect(form.save).to be(true) }.not_to change(EmergencyContact, :count)

      expect(emergency_contact.reload).to have_attributes(name: 'Maria Souza', relationship_type: 'mother', phone: '4532541000', position: 2)
    end
  end
end
