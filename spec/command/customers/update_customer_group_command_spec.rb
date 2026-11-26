require 'rails_helper'

RSpec.describe Customers::UpdateCustomerGroupCommand do
  let!(:tenant) { create(:tenant) }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU']) }
  let!(:customer) { create(:atua_customer, tenant:, name: 'GERDAU ACOMINAS S.A.') }

  it 'moves the customer into the group and stamps the change by hand' do
    described_class.call(customer, gerdau)

    expect(customer.reload.customer_group).to eq(gerdau)
    expect(customer.customer_group_edited_at).to be_present
  end

  it 'recalculates the freight expenses of the tenant' do
    expect { described_class.call(customer, gerdau) }.to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)
  end

  it 'does not recalculate again when the customer is already in the group' do
    described_class.call(customer, gerdau)

    expect { described_class.call(customer, gerdau) }.not_to have_enqueued_job(FreightExpenses::CalculateJob)
  end
end
