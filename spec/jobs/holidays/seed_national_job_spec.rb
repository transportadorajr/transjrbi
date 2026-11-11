require 'rails_helper'

RSpec.describe Holidays::SeedNationalJob do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  it 'registers the national holidays of every tenant' do
    allow(Holidays::SeedNationalCommand).to receive(:call).and_return(Holiday.none)

    described_class.perform_now

    expect(Holidays::SeedNationalCommand).to have_received(:call).with(tenant)
    expect(Holidays::SeedNationalCommand).to have_received(:call).with(other_tenant)
  end

  it 'is scheduled on the first day of december at 5h' do
    expect(GoodJob.configuration.cron.fetch(:holidays_national).slice(:cron, :class))
      .to eq(cron: '0 5 1 12 * America/Sao_Paulo', class: 'Holidays::SeedNationalJob')
  end
end
