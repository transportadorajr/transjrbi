require 'rails_helper'

RSpec.describe Admin::InitialLoadForm do
  let!(:tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 10, 14, 10)) { example.run } }

  it 'enqueues the initial load of the tenant' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-01-01', end_date: '2026-09-30')

    expect { expect(form.save).to be(true) }
      .to have_enqueued_job(Atua::InitialLoadJob).with(tenant.id, Date.new(2026, 1, 1), Date.new(2026, 9, 30), production_access: false)
    expect(form.tenant).to eq(tenant)
  end

  it 'asks for the production Atua when the production access flag is on', flipper: :atua_production_access do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-01-01', end_date: '2026-09-30')

    expect { expect(form.save).to be(true) }
      .to have_enqueued_job(Atua::InitialLoadJob).with(tenant.id, Date.new(2026, 1, 1), Date.new(2026, 9, 30), production_access: true)
  end

  it 'requires tenant, start date and end date' do
    form = described_class.new

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Empresa não pode ficar em branco', 'Data de início não pode ficar em branco', 'Data final não pode ficar em branco'])
    expect(Atua::InitialLoadJob).not_to have_been_enqueued
  end

  it 'rejects a start date in the future' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-10-15', end_date: '2026-10-14')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Data de início não pode ser posterior a hoje', 'Data final não pode ser anterior à data de início'])
  end

  it 'rejects an end date in the future' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-09-01', end_date: '2026-10-15')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Data final não pode ser posterior a hoje'])
    expect(Atua::InitialLoadJob).not_to have_been_enqueued
  end

  it 'rejects an end date before the start date' do
    form = described_class.new(tenant_id: tenant.id, start_date: '2026-09-01', end_date: '2026-08-31')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Data final não pode ser anterior à data de início'])
  end

  it 'suggests the period from September 2025 to September 2026' do
    form = described_class.with_default_period(tenant_id: tenant.id)

    expect(form.start_date).to eq(Date.new(2025, 9, 1))
    expect(form.end_date).to eq(Date.new(2026, 9, 30))
  end
end
