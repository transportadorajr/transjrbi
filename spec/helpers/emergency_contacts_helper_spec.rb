require 'rails_helper'

RSpec.describe EmergencyContactsHelper do
  describe '#emergency_contact_phone' do
    it 'formats national mobile and landline phones' do
      expect(helper.emergency_contact_phone('45999848077')).to eq('(45) 99984-8077')
      expect(helper.emergency_contact_phone('4532541000')).to eq('(45) 3254-1000')
    end

    it 'shows an international phone with its country code' do
      expect(helper.emergency_contact_phone('+5493772573358')).to eq('+54 93772573358')
    end
  end

  describe '#emergency_contact_phone_link' do
    it 'dials a national phone with the Brazilian country code' do
      expect(helper.emergency_contact_phone_link('45999848077')).to include('href="tel:+5545999848077"', '(45) 99984-8077')
    end

    it 'dials an international phone as it is' do
      expect(helper.emergency_contact_phone_link('+5493772573358')).to include('href="tel:+5493772573358"')
    end

    it 'shows a dash without a phone' do
      expect(helper.emergency_contact_phone_link(nil)).to eq('-')
    end
  end
end
