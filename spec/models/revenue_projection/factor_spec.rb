require 'rails_helper'

RSpec.describe RevenueProjection::Factor do
  it 'requires the weekday of a weekday bias' do
    factor = build(:revenue_projection_factor, factor_type: 'weekday_bias', wday: nil)

    expect(factor).not_to be_valid
    expect(factor.errors.attribute_names).to eq([:wday])
  end

  it 'stores a single factor of each kind per tenant' do
    factor = create(:revenue_projection_factor)

    expect { create(:revenue_projection_factor, tenant: factor.tenant) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
