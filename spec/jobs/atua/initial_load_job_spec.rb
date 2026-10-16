require 'rails_helper'

RSpec.describe Atua::InitialLoadJob do
  let!(:tenant) { create(:tenant) }

  before { allow(Atua::InitialLoadCommand).to receive(:call).and_return([]) }

  it 'runs the initial load of the tenant' do
    described_class.perform_now(tenant.id, Date.new(2026, 1, 1))

    expect(Atua::InitialLoadCommand).to have_received(:call).with(tenant, Date.new(2026, 1, 1), production_access: false)
  end

  it 'passes on the production access requested by the admin' do
    described_class.perform_now(tenant.id, Date.new(2026, 1, 1), production_access: true)

    expect(Atua::InitialLoadCommand).to have_received(:call).with(tenant, Date.new(2026, 1, 1), production_access: true)
  end
end
