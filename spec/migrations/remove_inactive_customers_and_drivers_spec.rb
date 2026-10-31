require 'rails_helper'
require Rails.root.join('db/migrate/20261031122827_remove_inactive_customers_and_drivers')

RSpec.describe RemoveInactiveCustomersAndDrivers do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  context 'when the tenant has inactive customers and drivers' do
    let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 1) }

    before do
      create(:atua_customer, tenant:, code: 1)
      create(:atua_transport_document, tenant:, driver_code: 1, taker_code: 1, sender_code: nil, recipient_code: nil, payer_code: nil, consignee_code: nil, issued_at: 13.months.ago)
    end

    it 'removes the customers and clears the drivers' do
      migration.up

      expect(tenant.atua_customers.count).to eq(0)
      expect(vehicle.reload.driver_code).to be_nil
    end
  end
end
