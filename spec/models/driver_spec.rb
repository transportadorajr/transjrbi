require 'rails_helper'

RSpec.describe Driver do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  context 'with a driver already registered' do
    let!(:driver) { create(:driver, tenant:, code: 760) }

    it 'rejects the same code twice in the tenant' do
      duplicate = build(:driver, tenant:, code: 760)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to eq(['já está em uso'])
    end

    it 'accepts the same code in another tenant' do
      expect(build(:driver, tenant: other_tenant, code: 760)).to be_valid
    end
  end

  it 'requires the code' do
    driver = described_class.new(tenant:)

    expect(driver).not_to be_valid
    expect(driver.errors.attribute_names).to contain_exactly(:code)
  end
end
