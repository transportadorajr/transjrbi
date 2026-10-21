require 'rails_helper'

RSpec.describe Admin::ImportForm do
  let!(:tenant) { create(:tenant) }
  let(:today) { Date.new(2026, 10, 14) }

  around { |example| travel_to(today.in_time_zone.change(hour: 10)) { example.run } }

  it 'enqueues the import of a movement report with its period' do
    form = described_class.new(tenant_id: tenant.id, report_type: 'manifests', start_date: '2026-10-01', end_date: '2026-10-14')

    expect { expect(form.save).to be(true) }
      .to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'manifests', Date.new(2026, 10, 1), today)
  end

  it 'enqueues a registry report without period' do
    form = described_class.new(tenant_id: tenant.id, report_type: 'customers', start_date: '2026-10-01', end_date: '2026-10-14')

    expect { expect(form.save).to be(true) }
      .to have_enqueued_job(Atua::ImportReportJob).with(tenant.id, 'customers', nil, nil)
  end

  it 'requires tenant, report and the period of a movement report' do
    form = described_class.new(report_type: 'manifests')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(
      ['Empresa não pode ficar em branco', 'Data inicial não pode ficar em branco', 'Data final não pode ficar em branco'],
    )
    expect(Atua::ImportReportJob).not_to have_been_enqueued
  end

  it 'rejects an unknown report' do
    form = described_class.new(tenant_id: tenant.id, report_type: 'invoices')

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['Relatório não está incluído na lista'])
  end

  it 'rejects an inverted or future period' do
    inverted = described_class.new(tenant_id: tenant.id, report_type: 'expenses', start_date: '2026-10-10', end_date: '2026-10-01')
    future = described_class.new(tenant_id: tenant.id, report_type: 'expenses', start_date: '2026-10-10', end_date: '2026-10-15')

    expect(inverted.save).to be_falsey
    expect(inverted.errors.full_messages).to eq(['Data final não pode ser anterior à data inicial'])
    expect(future.save).to be_falsey
    expect(future.errors.full_messages).to eq(['Data final não pode ser posterior a hoje'])
  end
end
