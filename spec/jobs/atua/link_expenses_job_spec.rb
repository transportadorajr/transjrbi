require 'rails_helper'

RSpec.describe Atua::LinkExpensesJob do
  let!(:tenant) { create(:tenant) }

  before do
    allow(Atua::LinkExpensesCommand).to receive(:call).and_return(0)
    allow(FreightExpenses::CalculateAdvanceIcmsCommand).to receive(:call)
      .and_return(FreightExpenses::CalculateAdvanceIcmsCommand::Result.new(saved: 0, removed: 0))
  end

  it 'links the expenses of the tenant and then recalculates the advance ICMS provisions' do
    described_class.perform_now(tenant.id)

    expect(Atua::LinkExpensesCommand).to have_received(:call).with(tenant).ordered
    expect(FreightExpenses::CalculateAdvanceIcmsCommand).to have_received(:call).with(tenant).ordered
  end

  context 'with the GoodJob adapter' do
    before { use_good_job_adapter(described_class) }

    it 'waits while the expenses of the same tenant are being linked' do
      mark_good_job_running(described_class.perform_later(tenant.id))
      waiting = described_class.perform_later(tenant.id)

      GoodJob.perform_inline

      expect(Atua::LinkExpensesCommand).not_to have_received(:call)
      expect(good_job_record(waiting).finished_at).to be_nil
    end
  end
end
