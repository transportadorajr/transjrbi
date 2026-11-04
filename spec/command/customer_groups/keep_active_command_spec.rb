require 'rails_helper'

RSpec.describe CustomerGroups::KeepActiveCommand do
  let(:tenant) { create(:tenant) }

  context 'with listed and unlisted customer groups' do
    let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELOR', terms: ['ARCELOR']) }
    let!(:sooro) { create(:customer_group, tenant:, name: 'SOORO', terms: ['SOORO'], activated_at: nil) }
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU']) }
    let!(:ambev) { create(:customer_group, tenant:, name: 'AMBEV S.A.') }
    let!(:other_tenant_group) { create(:customer_group, name: 'GERDAU') }

    it 'keeps active only the listed customer groups of the tenant' do
      expect(described_class.call(tenant, %w[ARCELOR SOORO MERCOSUL])).to contain_exactly(arcelor, sooro)

      expect(tenant.customer_groups.not_activated).to contain_exactly(gerdau, ambev)
      expect(other_tenant_group.reload).to be_activated
    end

    it 'can run again without changing the customer groups' do
      described_class.call(tenant, %w[ARCELOR SOORO])

      expect { described_class.call(tenant, %w[ARCELOR SOORO]) }.not_to(change { CustomerGroup.order(:id).pluck(:id, :activated_at) })
    end
  end
end
