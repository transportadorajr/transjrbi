require 'rails_helper'
require Rails.root.join('db/migrate/20261101001858_make_drivers_resource_writable')

RSpec.describe MakeDriversResourceWritable do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:drivers) { create(:resource, name: 'Motoristas', slug: 'drivers', writable: false) }
  let!(:vehicles) { create(:resource, name: 'Veículos', slug: 'vehicles', writable: false) }

  it 'makes only the drivers resource writable and can run again' do
    2.times { migration.up }

    expect(drivers.reload).to be_writable
    expect(vehicles.reload).not_to be_writable
  end

  it 'turns the drivers resource back to read only on rollback' do
    migration.up
    migration.down

    expect(drivers.reload).not_to be_writable
  end
end
