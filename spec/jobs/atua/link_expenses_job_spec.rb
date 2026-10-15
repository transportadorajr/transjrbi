require 'rails_helper'

RSpec.describe Atua::LinkExpensesJob do
  let!(:tenant) { create(:tenant) }

  before { allow(Atua::LinkExpensesCommand).to receive(:call).and_return(0) }

  it 'links the expenses of the tenant' do
    described_class.perform_now(tenant.id)

    expect(Atua::LinkExpensesCommand).to have_received(:call).with(tenant)
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
