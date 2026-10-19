require 'rails_helper'

RSpec.describe FreightExpenses::CalculateJob do
  let!(:tenant) { create(:tenant) }

  before do
    allow(FreightExpenses::CalculateCommissionsCommand).to receive(:call)
      .and_return(FreightExpenses::CalculateCommissionsCommand::Result.new(saved: 0, removed: 0))
    allow(FreightExpenses::CalculateTonnageCommand).to receive(:call)
      .and_return(FreightExpenses::CalculateTonnageCommand::Result.new(saved: 0, removed: 0))
    allow(FreightExpenses::CalculateInsuranceCommand).to receive(:call)
      .and_return(FreightExpenses::CalculateInsuranceCommand::Result.new(saved: 0, removed: 0))
  end

  it 'calculates the commissions, the tonnage costs and the cargo insurance of the tenant' do
    described_class.perform_now(tenant.id)

    expect(FreightExpenses::CalculateCommissionsCommand).to have_received(:call).with(tenant)
    expect(FreightExpenses::CalculateTonnageCommand).to have_received(:call).with(tenant)
    expect(FreightExpenses::CalculateInsuranceCommand).to have_received(:call).with(tenant)
  end

  context 'when the taker of the transport documents is grouped only by the name on them' do
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:rule) { create(:commission_rule, tenant:, customer_group: usiminas) }
    let!(:own_group) { create(:customer_group, tenant:, name: 'PESSOA 04263') }
    let!(:customer) { create(:atua_customer, tenant:, code: 6260, name: 'PESSOA 04263', customer_group: own_group) }
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, taker_code: 6260, taker_name: 'USINAS SIDERURGICAS DE MINAS GERAIS S/A - USIMINAS',
                                       destination_state: 'SP', freight_cents: 1_000_000, icms_cents: 120_000)
    end

    before { allow(FreightExpenses::CalculateCommissionsCommand).to receive(:call).and_call_original }

    it 'regroups the customers before calculating the commissions' do
      expect { described_class.perform_now(tenant.id) }.to change(FreightExpense, :count).by(1)

      expect(customer.reload.customer_group).to eq(usiminas)
      expect(FreightExpense.last).to have_attributes(transport_document:, commission_rule: rule, base_cents: 880_000, amount_cents: 17_600)
    end
  end

  context 'with the GoodJob adapter' do
    before { use_good_job_adapter(described_class) }

    it 'waits while the freight expenses of the same tenant are being calculated' do
      mark_good_job_running(described_class.perform_later(tenant.id))
      waiting = described_class.perform_later(tenant.id)

      GoodJob.perform_inline

      expect(FreightExpenses::CalculateCommissionsCommand).not_to have_received(:call)
      expect(good_job_record(waiting).finished_at).to be_nil
    end
  end
end
