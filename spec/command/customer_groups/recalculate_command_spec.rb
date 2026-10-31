require 'rails_helper'

RSpec.describe CustomerGroups::RecalculateCommand do
  let(:tenant) { create(:tenant) }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
  let!(:own_group) { create(:customer_group, tenant:, name: 'PESSOA 04263') }
  let!(:grouped) { create(:atua_customer, tenant:, code: 6260, name: 'PESSOA 04263', customer_group: own_group) }
  let!(:ungrouped) { create(:atua_customer, tenant:, code: 6490, name: 'USIMINAS IPATINGA') }
  let!(:unmatched) { create(:atua_customer, tenant:, code: 7000, name: 'DISTRIBUIDORA BH LTDA') }

  before do
    create(:atua_transport_document, tenant:, taker_code: 6260, taker_name: 'USINAS SIDERURGICAS DE MINAS GERAIS S/A - USIMINAS')
    create(:atua_transport_document, tenant:, taker_code: 7000, taker_name: 'DISTRIBUIDORA BH LTDA', issued_at: 1.month.ago)
  end

  it 'assigns the ungrouped customers and regroups every group with terms' do
    expect { expect(described_class.call(tenant)).to eq(3) }.not_to change(CustomerGroup, :count)

    expect(grouped.reload.customer_group).to eq(usiminas)
    expect(ungrouped.reload.customer_group).to eq(usiminas)
    expect(unmatched.reload.customer_group.name).to eq('DISTRIBUIDORA BH LTDA')
    expect(CustomerGroup.exists?(own_group.id)).to be(false)
  end

  it 'changes nothing when it runs again' do
    described_class.call(tenant)

    expect { expect(described_class.call(tenant)).to eq(0) }.not_to change(CustomerGroup, :count)
  end
end
