require 'rails_helper'
require Rails.root.join('db/migrate/20261118170825_assign_country_to_foreign_export_recipients')

RSpec.describe AssignCountryToForeignExportRecipients do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'when foreign recipients are registered without a known country' do
    let!(:ferrosider) { create(:atua_customer, name: 'FERROSIDER S/A', city: 'EXTERIOR', state: 'EX') }
    let!(:sunrise) { create(:atua_customer, name: 'Sunrise Internacional  Inc', city: 'EXTERIOR', state: 'EX') }
    let!(:qores) { create(:atua_customer, name: 'QORES SRL', city: 'EXTERIOR', state: 'EX') }
    let!(:edited) { create(:atua_customer, name: 'L ACERIE S A', city: 'EXTERIOR', state: 'EX', country_type: 'other', country_edited_at: 1.day.ago) }
    let!(:national) { create(:atua_customer, name: 'CJX SA', city: 'SAO PAULO', state: 'SP') }

    it 'assigns the researched country and keeps it as a manual choice' do
      migration.up

      expect([ferrosider, sunrise, qores].map { |customer| customer.reload.country_type }).to eq(%w[argentina united_states italy])
      expect([ferrosider, sunrise, qores].map { |customer| customer.reload.country_edited_at }).to all(be_present)
    end

    it 'keeps a country already chosen by hand' do
      expect { migration.up }.not_to(change { edited.reload.country_type })
    end

    it 'leaves customers with a Brazilian address untouched' do
      migration.up

      expect(national.reload).to have_attributes(country_type: nil, country_edited_at: nil)
    end

    it 'restores the customers on rollback' do
      migration.up
      migration.down

      expect(ferrosider.reload).to have_attributes(country_type: nil, country_edited_at: nil)
      expect(edited.reload.country_type).to eq('other')
    end
  end
end
