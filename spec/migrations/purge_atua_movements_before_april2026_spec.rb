require 'rails_helper'
require Rails.root.join('db/migrate/20261104125336_purge_atua_movements_before_april2026')

RSpec.describe PurgeAtuaMovementsBeforeApril2026 do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with records before and after April 2026' do
    let!(:tenant) { create(:tenant) }
    let!(:new_manifest) { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 4, 1)) }
    let!(:new_document) { create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 4, 1, 8)) }
    let!(:new_expense) { create(:atua_expense, tenant:, posted_on: Date.new(2026, 4, 1)) }

    before do
      create(:atua_manifest, tenant:, issued_on: Date.new(2026, 3, 31))
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 3, 31, 8))
      create(:atua_expense, tenant:, posted_on: Date.new(2026, 3, 31))
    end

    it 'keeps only the manifests, transport documents and expenses from April 2026 on' do
      migration.up

      expect(Atua::Manifest.all).to eq([new_manifest])
      expect(Atua::TransportDocument.all).to eq([new_document])
      expect(Atua::Expense.all).to eq([new_expense])
    end
  end
end
