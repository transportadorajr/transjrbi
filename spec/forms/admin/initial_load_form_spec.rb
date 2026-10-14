require 'rails_helper'

RSpec.describe Admin::InitialLoadForm do
  let!(:tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 10, 14, 10)) { example.run } }

  it 'enqueues the initial load of the tenant' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-01-01')

    expect { expect(form.save).to be(true) }.to have_enqueued_job(Atua::InitialLoadJob).with(tenant.id, Date.new(2026, 1, 1))
    expect(form.tenant).to eq(tenant)
  end

  it 'requires tenant and start date' do
    form = described_class.new

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Empresa não pode ficar em branco', 'Data de início não pode ficar em branco'])
    expect(Atua::InitialLoadJob).not_to have_been_enqueued
  end

  it 'rejects a start date in the future' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-10-15')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Data de início não pode ser posterior a hoje'])
  end
end
