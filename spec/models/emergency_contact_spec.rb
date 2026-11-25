require 'rails_helper'

RSpec.describe EmergencyContact do
  describe 'validations' do
    it 'requires the name and a positive position' do
      emergency_contact = described_class.new(name: '', position: 0)

      expect(emergency_contact).not_to be_valid
      expect(emergency_contact.errors.attribute_names).to include(:name, :position)
    end

    it 'accepts a contact without relationship and phone imported from the spreadsheet' do
      expect(build(:emergency_contact, relationship_type: nil, phone: nil)).to be_valid
    end

    it 'rejects an unknown relationship' do
      expect(build(:emergency_contact, relationship_type: 'neighbor')).not_to be_valid
    end
  end

  describe '.normalize_phone' do
    it 'keeps only the digits of a national phone' do
      expect(described_class.normalize_phone('(45)9.9984-8077')).to eq('45999848077')
      expect(described_class.normalize_phone('(51)9. 8925-9805')).to eq('51989259805')
    end

    it 'keeps the plus sign of an international phone' do
      expect(described_class.normalize_phone('+54 9 3772 57-3358')).to eq('+5493772573358')
    end

    it 'returns nil without digits' do
      expect(described_class.normalize_phone(' - ')).to be_nil
    end
  end

  describe '.valid_phone?' do
    it 'accepts national phones with the area code and international phones with the country code' do
      expect(described_class.valid_phone?('4599848077')).to be(true)
      expect(described_class.valid_phone?('45999848077')).to be(true)
      expect(described_class.valid_phone?('+5493772573358')).to be(true)
    end

    it 'rejects a national phone with a digit missing or left over' do
      expect(described_class.valid_phone?('999848077')).to be(false)
      expect(described_class.valid_phone?('459998480771')).to be(false)
      expect(described_class.valid_phone?('+5499')).to be(false)
    end
  end

  describe 'employee scopes' do
    let!(:with_contact) { create(:emergency_contact).employee }
    let!(:without_contact) { create(:employee, tenant: with_contact.tenant, legal_id: nil) }

    it 'filters the employees by having an emergency contact' do
      expect(Employee.without_emergency_contact).to contain_exactly(without_contact)
      expect(Employee.by_emergency_contact('missing')).to contain_exactly(without_contact)
      expect(Employee.by_emergency_contact('registered')).to contain_exactly(with_contact)
    end
  end

  describe 'employee contacts' do
    let!(:employee) { create(:employee) }
    let!(:second) { create(:emergency_contact, employee:, position: 2, name: 'Segundo') }
    let!(:first) { create(:emergency_contact, employee:, position: 1, name: 'Primeiro') }

    it 'lists the contacts by priority' do
      expect(employee.emergency_contacts).to eq([first, second])
    end
  end
end
