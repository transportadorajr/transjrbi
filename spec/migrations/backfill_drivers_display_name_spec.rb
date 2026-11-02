require 'rails_helper'
require Rails.root.join('db/migrate/20261102172300_backfill_drivers_display_name')

RSpec.describe BackfillDriversDisplayName do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  before do
    create(:atua_vehicle, tenant:, driver_code: 2426, driver_name: 'FABIO JOSE CAUZ')
    create(:atua_vehicle, tenant:, driver_code: 2426, driver_name: 'FABIO JOSE CAUZ')
    create(:atua_vehicle, tenant:, driver_code: 4187, driver_name: 'ALIOR JOSE CAUZ')
    create(:atua_transport_document, tenant:, driver_code: 4361, driver_name: 'PEDRO HENRIQUE LUTZ')
    create(:atua_transport_document, tenant: other_tenant, driver_code: 9000, driver_name: 'SAMIR REINILDES MOLL')
  end

  it 'registers the display names of the listed drivers found on vehicles and transport documents of every tenant' do
    expect { migration.up }.to change(Driver, :count).by(3)

    expect(Driver.order(:code).pluck(:tenant_id, :code, :display_name)).to eq(
      [
        [tenant.id, 2426, 'FABIO CAUZ'],
        [tenant.id, 4361, 'PEDRO LUTZ'],
        [other_tenant.id, 9000, 'SAMIR'],
      ],
    )
  end

  context 'with a driver whose display name was already edited' do
    let!(:driver) { create(:driver, tenant:, code: 2426, display_name: 'CAUZ') }

    it 'keeps the edited display name and can run again' do
      2.times { migration.up }

      expect(driver.reload.display_name).to eq('CAUZ')
      expect(Driver.count).to eq(3)
    end
  end
end
